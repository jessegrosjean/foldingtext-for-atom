AttributedString = require '../../core/attributed-string'
{repeat, replace, leadingTabs} = require '../helpers'
Line = require '../line'

unless String.prototype.getString
  String.prototype.getString = ->
    @toString()

unless String.prototype.appendString
  String.prototype.appendString = (string) ->
    @toString() + string

unless String.prototype.deleteCharactersInRange
  String.prototype.deleteCharactersInRange = (location, length) ->
    this.substr(0, location) + this.substr(location + length)

class OutlineLine extends Line

  @parent: null
  @item: null
  @buffer: null

  constructor: (@buffer, @item) ->

  getText: ->
    bodyText = @item.bodyText
    tabCount = @getTabCount()
    tabs = repeat('\t', tabCount)
    tabs + bodyText

  substr: (index) ->
    tabCount = @getTabCount()
    if index < tabCount
      result = new AttributedString(repeat('\t', tabCount - index))
      result.appendString(@item.attributedBodyText)
      result
    else
      @item.getAttributedBodyTextSubstring(index - @getTabCount(), -1)

  append: (content) ->
    end = @getCharacterCount() - 1
    @setTextInRange(content, end, end)

  getTabCount: ->
    (@item.depth - @buffer.hoistedItem.depth) - 1

  updateItemIndent: (indentDelta) ->
    if indentDelta
      nextItem = @item.nextItem
      if @item.parent
        @item.outline.removeItem(@item)
        @item.indent += indentDelta
        @item.outline.insertItemBefore(@item, nextItem)
      else
        @item.indent += indentDelta

  deleteText: (start, end) ->
    if start is end
      return

    startString = @getText()
    startTabs = leadingTabs(startString)
    itemIndentDelta = 0

    if start > startTabs
      # Just delete body text
      start -= startTabs
      end -= startTabs
    else if end <= startTabs
      # Just adjust indent
      itemIndentDelta -= (end - start)
      start = end
    else
      while startString[end] is '\t'
        itemIndentDelta++
        end++

      while start <= end and startString[start] is '\t'
        itemIndentDelta--
        start++

      start -= startTabs
      end -= startTabs

    if deleteLength = (end - start)
      @item.replaceBodyTextInRange('', start, deleteLength)

    @updateItemIndent(itemIndentDelta)

  insertText: (text, location) ->
    if text.length is 0
      return

    startString = @getText()
    startTabs = leadingTabs(startString)
    itemIndentDelta = 0

    if location > startTabs
      location -= startTabs
    else
      # Remove startString tabs that trail the insert location and append them
      # to the inserted text.
      trimStartTabs = 0
      while startString[location + trimStartTabs] is '\t'
        itemIndentDelta--
        trimStartTabs++
      if trimStartTabs
        text = text.appendString(repeat('\t', trimStartTabs))

      # Trim tabs from front of inserted text and account for them in ident.
      insertString = text.getString()
      trimInsertTabs = 0
      while insertString[trimInsertTabs] is '\t'
        itemIndentDelta++
        trimInsertTabs++
      if trimInsertTabs
        text = text.deleteCharactersInRange(0, trimInsertTabs)

      # Final insert location in body text
      location = 0

    if text.length
      @item.replaceBodyTextInRange(text, location, 0)

    @updateItemIndent(itemIndentDelta)

  setTextInRange: (text, start, end) ->
    textString = text.getString()

    if delta = (textString.length - (end - start))
      each = @parent
      while each
        each.characterCount += delta
        each = each.parent

    unless @buffer.isUpdatingBufferFromOutline
      @buffer.isUpdatingOutlineFromBuffer++

      if start isnt end
        @deleteText(start, end)

      if textString.length
        @insertText(text, start)

      @buffer.isUpdatingOutlineFromBuffer--

module.exports = OutlineLine