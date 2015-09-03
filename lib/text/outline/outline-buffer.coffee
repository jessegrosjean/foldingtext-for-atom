Mutation = require '../../core/mutation'
{repeat, replace} = require '../helpers'
{CompositeDisposable} = require 'atom'
OutlineLine = require './outline-line'
Outline = require '../../core/outline'
Item = require '../../core/item'
Buffer = require '../buffer'
Range = require '../range'

class OutlineBuffer extends Buffer

  constructor: (outline, @outlineEditor) ->
    super()
    @isUpdatingBuffer = 0
    @isUpdatingOutline = 0
    @itemsToLinesMap = new Map
    @subscriptions = new CompositeDisposable()
    @outline = outline or Outline.buildOutlineSync()
    @outline.retain()
    @subscriptions.add @outline.onDidChange @outlineDidChange.bind(this)
    @subscriptions.add @outline.onDidDestroy => @destroy()

  outlineDidChange: (mutation) ->
    if @isUpdatingOutline
      return

    @emitter.emit 'will-process-outline-mutation', mutation

    target = mutation.target

    switch mutation.type
      when Mutation.ATTRIBUTE_CHANGED
        if mutation.attributeName is 'indent'
          if line = @getLineForItem(target)
            if mutation.attributeOldValue
              oldIndent = parseInt(mutation.attributeOldValue, 10)
            else
              oldIndent = 1
            newIndent = target.indent
            delta = newIndent - oldIndent
            row = line.getRow()

            @isUpdatingBuffer++
            if delta > 0
              @setTextInRange(repeat('\t', delta), new Range([row, oldIndent - 1], [row, oldIndent - 1]))
            else if delta < 0
              @setTextInRange('', new Range([row, oldIndent - 1 + delta], [row, oldIndent - 1]))
            @isUpdatingBuffer--

      when Mutation.BODT_TEXT_CHANGED
        if line = @getLineForItem(target)
          start = mutation.insertedTextLocation
          text = target.bodyText.substr(start, mutation.insertedTextLength)
          indentTabs = line.getTabCount()
          start += indentTabs
          end = start + mutation.replacedText.length
          row = line.getRow()
          range = new Range([row, start], [row, end])

          @isUpdatingBuffer++
          @setTextInRange(text, range)
          @isUpdatingBuffer--

      when Mutation.CHILDREN_CHANGED
        if mutation.removedItems.length
          # Remove lines
          removeStart = undefined
          removeCount = 0

          removeRangeIfDefined = =>
            @isUpdatingBuffer++
            @removeLines(removeStart, removeCount)
            @isUpdatingBuffer--
            removeStart = undefined
            removeCount = 0

          for each in mutation.getFlattendedRemovedItems()
            if line = @getLineForItem(each)
              removeStart ?= line.getRow()
              removeCount++
            else if removeStart
              removeRangeIfDefined()
          removeRangeIfDefined()

        else if mutation.addedItems.length
          # Ignore if lines shouldn't be in this buffer
          if target isnt @getHoistedItem()
            if not @isVisible(target) or not @isExpanded(target)
              return

          # Insert lines
          addedLines = []

          addLineForItemIfVisible = (item) =>
            if @isVisible(item)
              addedLines.push(new OutlineLine(this, item))
              eachChild = item.firstChild
              while eachChild
                addLineForItemIfVisible(eachChild)
                eachChild = eachChild.nextSibling

          for each in mutation.addedItems
            addLineForItemIfVisible(each)

          if addedLines.length
            insertBeforeItem = addedLines[addedLines.length - 1].item.nextItem
            while insertBeforeItem and not (insertBeforeLine = @getLineForItem(insertBeforeItem))
              insertBeforeItem = insertBeforeItem.nextItem

            if insertBeforeLine
              row = insertBeforeLine.getRow()
            else
              insertAfterItem = addedLines[0].item.previousItem
              while insertAfterItem and not (insertAfterLine = @getLineForItem(insertAfterItem))
                insertAfterItem = insertAfterItem.nextItem

              if insertAfterLine
                row = insertAfterLine.getRow() + 1
              else
                row = @getLineCount()

            @isUpdatingBuffer++
            @insertLines(row, addedLines)
            @isUpdatingBuffer--

    @emitter.emit 'did-process-outline-mutation', mutation

  destroy: ->
    unless @destroyed
      @subscriptions.dispose()
      @outline.release()
      super()

  ###
  Section: Events
  ###

  onWillProcessOutlineMutation: (callback) ->
    @emitter.on 'will-process-outline-mutation', callback

  onDidProcessOutlineMutation: (callback) ->
    @emitter.on 'did-process-outline-mutation', callback

  ###
  Section: Outline Editor Cover
  ###

  isVisible: (item) ->
    @outlineEditor?.isVisible(item) ? true

  isExpanded: (item) ->
    @outlineEditor?.isExpanded(item) ? true

  getHoistedItem: ->
    @outlineEditor?.getHoistedItem() ? @outline.root

  ###
  Section: Lines
  ###

  getLineForItem: (item) ->
    @itemsToLinesMap.get(item)

  getItemRangeFromRange: (range) ->
    startItem = @getLine(range.start.row).item
    endItem = @getLine(range.end.row).item
    {} =
      startItem: startItem
      _startItemOriginalDepth: startItem.depth
      spanLocation: range.start.column
      endItem: endItem
      _endItemOriginalDepth: endItem.depth
      endOffset: range.end.column

  getRangeFromItemRange: (startItem, spanLocation, endItem, endOffset) ->
    unless startItem instanceof Item
      {startItem, _startItemOriginalDepth, spanLocation, endItem, _endItemOriginalDepth, endOffset} = startItem

    visibleStartItem = startItem
    while visibleStartItem and not @isVisible(visibleStartItem)
      visibleStartItem = visibleStartItem.previousItem
    if startItem isnt visibleStartItem
      startItem = visibleStartItem
      unless startItem
        return new Range
      spanLocation = @getLineForItem(startItem).getTabCount()
      _startItemOriginalDepth = startItem.depth

    visibleEndItem = endItem
    while visibleEndItem and not @isVisible(visibleEndItem)
      visibleEndItem = visibleEndItem.previousItem
    if endItem isnt visibleEndItem
      endItem = visibleEndItem
      unless endItem
        return new Range
      endOffset = @getLineForItem(endItem).getTabCount()
      _endItemOriginalDepth = endItem.depth

    startLine = @getLineForItem(startItem)
    startRow = startLine.getRow()
    spanLocation ?= 0
    if endItem
      endLine = @getLineForItem(endItem)
      endRow = endLine.getRow()
      endOffset ?= 0
    else
      endItem = startItem
      endRow = startRow
      endOffset = spanLocation

    if _startItemOriginalDepth? and _endItemOriginalDepth?
      spanLocation += startItem.depth - _startItemOriginalDepth
      endOffset += endItem.depth - _endItemOriginalDepth

    new Range([startRow, spanLocation], [endRow, endOffset])

  insertLines: (row, lines) ->
    insertBefore = @getLine(row)?.item or @getHoistedItem().nextSibling

    for each in lines
      @itemsToLinesMap.set(each.item, each)

    unless @isUpdatingBuffer
      items = (each.item for each in lines)
      @isUpdatingOutline++
      @outline.insertItemsBefore(items, insertBefore)
      @isUpdatingOutline--

    super(row, lines)

  removeLines: (row, count) ->
    lines = []
    @iterateLines row, count, (each) =>
      @itemsToLinesMap.delete(each.item)
      lines.push(each)

    unless @isUpdatingBuffer
      @isUpdatingOutline++
      for each in lines
        @outline.removeItem(each.item)
      @isUpdatingOutline--

    super(row, count)

  ###
  Section: Text Line Override
  ###

  createLineFromText: (text) ->
    item = @outline.createItem()
    item.indent = @getHoistedItem().depth + 1
    outlineLine = new OutlineLine(this, item)
    outlineLine.setTextInRange(text, 0, 0)
    outlineLine

module.exports = OutlineBuffer