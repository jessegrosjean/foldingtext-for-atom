AttributedString = require '../../core/attributed-string'
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

  deleteText: (start, end) ->
    if start is end
      return

    startText = @getText()
    startTabs = leadingTabs(startText)
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
      while startText[end] is '\t'
        itemIndentDelta++
        end++

      while start <= end and startText[start] is '\t'
        itemIndentDelta--
        start++

      start -= startTabs
      end -= startTabs

    if deleteLength = (end - start)
      @item.replaceBodyTextInRange('', start, deleteLength)

    if itemIndentDelta
      nextItem = @item.nextItem
      if @item.parent
        @item.outline.removeItem(@item)
        @item.indent += itemIndentDelta
        @item.outline.insertItemBefore(@item, nextItem)
      else
        @item.indent += itemIndentDelta

  insertText: (text, location) ->
    if text.getString
      insertString = text.getString()
    else
      insertString = text

    if insertString.length is 0
      return

    startText = @getText()
    startTabs = leadingTabs(startText)
    insertText = insertString
    itemIndentDelta = 0

    if location > startTabs
      location -= startTabs
    else
      insertStart = 0
      insertEnd = insertString.length
      appendAfterInsert = ''

      # Trim tabs from front of inserted text accounting for them in indent delta
      while insertText[trimLength] is '\t'
        itemIndentDelta++
        insertStart++

      # Collect original tabs trailing start


      # Append tabs to end of insert text
      if location < startTabs
        diff = startTabs - location
        itemIndentDelta -= diff
        appendAfterInsert = repeat('\t', diff)

      while startText[location] is '\t'
        location--


      if insertStart isnt insertEnd
        @item.replaceBodyTextInRange(text, location, 0)

      if appendAfterInsert
        @item.replaceBodyTextInRange(appendAfterInsert, location, 0)

  ###
  insertText: (text, location) ->
    unless @buffer.isUpdatingBufferFromOutline

    if insertString.length is 0
      return

    @buffer.isUpdatingOutlineFromBuffer++

    startText = @getText()
    startTabs = leadingTabs(startText)
    insertText = insertString
    insertTabs = leadingTabs(insertText)

    if location > startTabs
      location -= startTabs
    else
      # Trim tabs from front of inserted text
      trimStart = 0
      while insertText[trimStart] is '\t'
        indentDelta++
        location++
        trimStart++

      # Append tabs to end of inserted text
      if location < startTabs
        diff = startTabs - location
        indentDelta -= diff
        repeat('\t', diff)


      if location is startTabs
        # Trim tabs from front of text
      trimStart = 0
      while insertText[trimStart] is '\t'
        indentDelta++
        location++
        trimStart++
    else




    @buffer.isUpdatingOutlineFromBuffer--

  ###

  setTextInRange: (text, start, end) ->
    if text.getString
      textString = text.getString()
    else
      textString = text

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
        @insertText(text, end)

      @buffer.isUpdatingOutlineFromBuffer--



    ###
    unless @buffer.isUpdatingBufferFromOutline
      if text.getString
        textString = text.getString()
      else
        textString = text

    @buffer.isUpdatingOutlineFromBuffer++

    # 1. Update line character count
    if delta = (text.length - (end - start))
      each = @parent
      while each
        each.characterCount += delta
        each = each.parent

    # 2. Count tabs calc final text
    startText = @getText()
    startTabs = leadingTabs(startText)
    insertedText = textString
    insertTabs = leadingTabs(insertedText)
    replacedText = startText.substr(start, end)
    replaceTabs = leadingTabs(replacedText)
    finalText = replace(startText, start, end, insertedText)
    finalTabs = leadingTabs(finalText)

    itemLocation = start
    itemReplaceLength = end - start

    if itemReplaceLength


    # 3. Determine item indent delta, insertText, and replace range
    itemIndentDelta = 0
    itemInsertText = textString
    itemStart = start
    itemEnd = end
    itemReplaceLength = end - start

    if itemStart > startTabs
      # OK
    else if itemStart is startTabs
    else if itemStart < startTabs


    # 4. Update item body text if needed
    if itemInsertText or itemReplaceLength
      @item.replaceBodyTextInRange(itemInsertText, itemStart, itemReplaceLength)

    # 5. Update item indent if changed
    if itemIndentDelta
      nextItem = @item.nextItem
      if @item.parent
        @item.outline.removeItem(@item)
        @item.indent += indentDelta
        @item.outline.insertItemBefore(@item, nextItem)
      else
        @item.indent += indentDelta

    @buffer.isUpdatingOutlineFromBuffer--
    ###

    ###
    # 2.
    startText = @getText()
    startTabs = leadingTabs(startText)

    insertedText = textString
    insertTabs = leadingTabs(insertedText)

    replacedText = startText.substr(start, end)
    replaceTabs = leadingTabs(replacedText)

    finalText = replace(startText, start, end, insertedText)
    finalTabs = leadingTabs(finalText)

    indentDelta = 0

    if start > startTabs
      # good to go, no level change
    else if start is startTabs
      if replacedText
      else

        if insertTabs
        else
          insertedText = (startText.substr()) + insertedText

    else if start < startTabs

      if replacedText.length
      else
        if insertTabs

        else
          insertedText = (startText.substr()) + insertedText

      # Level can change if insert text has tabs
      # Level can change if replacedText.length and





    if start.indent is end.indent is 0
      # good to go
    else if



    indentDelta = 0

    if insertTabs
      indentDelta += insertTabs
      text = text.substr(insertTabs)

    if

    if indentDelta
      nextItem = @item.nextItem
      if @item.parent
        @item.outline.removeItem(@item)
        @item.indent += indentDelta
        @item.outline.insertItemBefore(@item, nextItem)
      else
        @item.indent += indentDelta


    # Need to extend/contract start/end and text as needed

    if text.length or (end - start)
      @item.replaceBodyTextInRange(text, start, end - start)

    @buffer.isUpdatingOutlineFromBuffer--
    ###

  OLDsetTextInRange: (text, start, end) ->
    unless @buffer.isUpdatingBufferFromOutline
      if text.getString
        textString = text.getString()
      else
        textString = text

      @buffer.isUpdatingOutlineFromBuffer++

      oldText = @getText()
      oldLeadingTabs = leadingTabs(oldText)
      newText = replace(oldText, start, end, textString)
      newLeadingTabs = leadingTabs(newText)



      # minimal
      oldDeleteBodyTextStart = Math.max(0, oldLeadingTabs - start)
      oldDeleteBodyTextEnd = Math.max(0, oldLeadingTabs - end)
      if start <= oldLeadingTabs
        leadingTabs(textString)



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