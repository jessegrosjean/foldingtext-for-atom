{repeat, replace, leadingTabs} = require '../helpers'
Line = require '../line'

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

  getCharacterCount: ->
    @getText().length + 1 # \n

  substr: (index) ->
    @item.getAttributedBodyTextSubstring(index, -1)

  append: (content) ->
    end = @getCharacterCount() - 1
    @setTextInRange(content, end, end)

  getTabCount: ->
    (@item.depth - @buffer.hoistedItem.depth) - 1

  setTextInRange: (text, start, end) ->
    unless @buffer.isUpdatingBufferFromOutline
      if text.string
        textString = text.string()
      else
        textString = text

      @buffer.isUpdatingOutlineFromBuffer++

      oldText = @getText()
      oldLeadingTabs = leadingTabs(oldText)
      newText = replace(oldText, start, end, textString)
      newLeadingTabs = leadingTabs(newText)

      bodyText = newText.substr(newLeadingTabs)
      if @item.bodyText isnt bodyText
        @item.bodyText = bodyText

      if delta = (newLeadingTabs - oldLeadingTabs)
        nextItem = @item.nextItem
        if @item.parent
          @item.outline.removeItem(@item)
          @item.indent += delta
          @item.outline.insertItemBefore(@item, nextItem)
        else
          @item.indent += delta

      #@item.replaceBodyTextInRange(text, start, end - start)
      @buffer.isUpdatingOutlineFromBuffer--

    if delta = (text.length - (end - start))
      each = @parent
      while each
        each.characterCount += delta
        each = each.parent

module.exports = OutlineLine

























###
replaceLineTextInRange: (line, start, length, text) ->
  # Update Item state based on text change. Need to calcuate item body text
  # range to replace and items new indent level.
  oldText = @getLineText(line)
  oldLeadingTabs = leadingTabs(oldText)
  newText = replace(oldText, start, length, text)
  newLeadingTabs = leadingTabs(newText)
  depthDelta = newLeadingTabs - oldLeadingTabs

  item = line.data
  outline = item.outline
  outline.beginChanges()


  if start <= oldLeadingTabs
    start = oldLeadingTabs

  # Replace item body text if changed
  item.replaceBodyTextInRange(insertedText, start, length)

  # Reinsert item if depth changed
  if depthDelta
    depth = item.depth
    referenceItem = item.nextItem
    outline.removeItem(item)
    outline.insertItemBefore(item, depth + depthDelta, referenceItem)

  line.setCharacterCount(newText.length)
  outline.endChanges()
###