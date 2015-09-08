{CompositeDisposable} = require 'atom'
LineIndex = require '../line-index'
ItemSpan = require './item-span'
Mutation = require '../mutation'
assert = require 'assert'

class ItemIndex extends LineIndex

  constructor: (@item, @editor) ->
    super()
    @isUpdatingIndex = 0
    @isUpdatingItems = 0
    @setItem(@item)

  setItem: (@item) ->
    @isUpdatingIndex++
    @removeSpans(0, @getSpanCount())
    @subscriptions?.dispose()
    @subscriptions = new CompositeDisposable
    @subscriptions.add @item.outline.onDidChange @outlineDidChange.bind(this)
    @subscriptions.add @item.outline.onDidDestroy => @destroy()
    @itemsToItemSpansMap = new Map
    if @item
      assert(@item.isInOutline)
      itemSpans = []
      for each in @item.descendants
        itemSpans.push(new ItemSpan(each))
      @insertSpans(0, itemSpans)
    @isUpdatingIndex--

  outlineDidChange: (mutation) ->
    if @isUpdatingItems
      return

    @isUpdatingIndex++
    target = mutation.target
    switch mutation.type
      when Mutation.BODT_TEXT_CHANGED
        if itemSpan = @getItemSpanForItem(target)
          localLocation = mutation.insertedTextLocation
          insertedString = target.bodyText.substr(localLocation, mutation.insertedTextLength)
          location = itemSpan.getLocation() + localLocation
          itemSpan.replaceRange(location, mutation.replacedText.length, insertedString)

      when Mutation.CHILDREN_CHANGED
        if mutation.removedItems.length
          @_outlineDidRemoveItems(target, mutation.getFlattendedRemovedItems())
        if mutation.addedItems.length
          @_outlineDidRemoveItems(target, mutation.addedItems)
    @isUpdatingIndex--

  _outlineDidRemoveItems: (target, removedDescendants) ->
    removeStartIndex = undefined
    removeCount = 0

    removeRangeIfDefined = =>
      @removeLines(removeStartIndex, removeCount)
      removeStartIndex = undefined
      removeCount = 0

    for each in removedDescendants
      if itemSpan = @getItemSpanForItem(each)
        removeStartIndex ?= itemSpan.getSpanIndex()
        removeCount++
      else if removeStartIndex
        removeRangeIfDefined()
    removeRangeIfDefined()

  _outlineDidAddItems: (target, addedChildren) ->
    if target isnt @getHoistedItem()
      if not @isVisible(target) or not @isExpanded(target)
        return

    addedItemSpans = []
    addItemSpanForItemIfVisible = (item) =>
      if @isVisible(item)
        addedItemSpans.push(new ItemSpan(item))
        eachChild = item.firstChild
        while eachChild
          addItemSpanForItemIfVisible(eachChild)
          eachChild = eachChild.nextSibling

    for each in addedChildren
      addItemSpanForItemIfVisible(each)

    if addedItemSpans.length
      insertBeforeItem = addedItemSpans[addedItemSpans.length - 1].item.nextItem
      while insertBeforeItem and not (insertBeforeLine = @getItemSpanForItem(insertBeforeItem))
        insertBeforeItem = insertBeforeItem.nextItem
      if insertBeforeLine
        insertIndex = insertBeforeLine.getSpanIndex()
      else
        insertAfterItem = addedItemSpans[0].item.previousItem
        while insertAfterItem and not (insertAfterLine = @getItemSpanForItem(insertAfterItem))
          insertAfterItem = insertAfterItem.nextItem
        if insertAfterLine
          insertIndex = insertAfterLine.getSpanIndex() + 1
        else
          insertIndex = @getLineCount()
      @insertSpans(insertIndex, addedItemSpans)

  destroy: ->
    @subscriptions.dispose()
    super()

  ###
  Section: Visibility
  ###

  isVisible: (item) ->
    @editor?.isVisible(item) ? true

  isExpanded: (item) ->
    @editor?.isExpanded(item) ? true

  ###
  Section: Characters
  ###

  deleteRange: (location, length) ->
    unless length
      return
    super(location, length)

  insertString: (location, text) ->
    unless text
      return
    super(location, text)

  ###
  Section: Spans
  ###

  createSpan: (text) ->
    new ItemSpan(@item.outline.createItem(text))

  getItemSpanForItem: (item) ->
    @itemsToItemSpansMap.get(item)

  insertSpans: (spanIndex, itemSpans) ->
    insertBefore = @getSpan(spanIndex)?.item or @item.nextSibling

    for each in itemSpans
      @itemsToItemSpansMap.set(each.item, each)

    unless @isUpdatingIndex
      items = (each.item for each in itemSpans)
      @isUpdatingItems++
      @item.outline.insertItemsBefore(items, insertBefore)
      @isUpdatingItems--

    super(spanIndex, itemSpans)

  removeSpans: (spanIndex, deleteCount) ->
    lineSpans = []
    @iterateLines spanIndex, deleteCount, (each) =>
      @itemsToItemSpansMap.delete(each.item)
      lineSpans.push(each)

    unless @isUpdatingIndex
      @isUpdatingItems++
      for each in lineSpans
        @item.outline.removeItem(each.item)
      @isUpdatingItems--

    super(spanIndex, deleteCount)

module.exports = ItemIndex


###
  constructor: (outline, @editor) ->
    super()

  outlineDidChange: (mutation) ->
    if @isUpdatingItems
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

            @isUpdatingIndex++
            if delta > 0
              @setTextInRange(repeat('\t', delta), new Range([row, oldIndent - 1], [row, oldIndent - 1]))
            else if delta < 0
              @setTextInRange('', new Range([row, oldIndent - 1 + delta], [row, oldIndent - 1]))
            @isUpdatingIndex--

      when Mutation.BODT_TEXT_CHANGED
        if line = @getLineForItem(target)
          start = mutation.insertedTextLocation
          text = target.bodyText.substr(start, mutation.insertedTextLength)
          indentTabs = line.getTabCount()
          start += indentTabs
          end = start + mutation.replacedText.length
          row = line.getRow()
          range = new Range([row, start], [row, end])

          @isUpdatingIndex++
          @setTextInRange(text, range)
          @isUpdatingIndex--

      when Mutation.CHILDREN_CHANGED
        if mutation.removedItems.length
          # Remove lines
          removeStartIndex = undefined
          removeCount = 0

          removeRangeIfDefined = =>
            @isUpdatingIndex++
            @removeLines(removeStartIndex, removeCount)
            @isUpdatingIndex--
            removeStartIndex = undefined
            removeCount = 0

          for each in mutation.getFlattendedRemovedItems()
            if line = @getLineForItem(each)
              removeStartIndex ?= line.getRow()
              removeCount++
            else if removeStartIndex
              removeRangeIfDefined()
          removeRangeIfDefined()

        else if mutation.addedItems.length
          # Ignore if lines shouldn't be in this buffer
          if target isnt @getHoistedItem()
            if not @isVisible(target) or not @isExpanded(target)
              return

          # Insert lines
          addedItemSpans = []

          addLineForItemIfVisible = (item) =>
            if @isVisible(item)
              addedItemSpans.push(new OutlineLine(this, item))
              eachChild = item.firstChild
              while eachChild
                addLineForItemIfVisible(eachChild)
                eachChild = eachChild.nextSibling

          for each in mutation.addedItems
            addLineForItemIfVisible(each)

          if addedItemSpans.length
            insertBeforeItem = addedItemSpans[addedItemSpans.length - 1].item.nextItem
            while insertBeforeItem and not (insertBeforeLine = @getLineForItem(insertBeforeItem))
              insertBeforeItem = insertBeforeItem.nextItem

            if insertBeforeLine
              row = insertBeforeLine.getRow()
            else
              insertAfterItem = addedItemSpans[0].item.previousItem
              while insertAfterItem and not (insertAfterLine = @getLineForItem(insertAfterItem))
                insertAfterItem = insertAfterItem.nextItem

              if insertAfterLine
                row = insertAfterLine.getRow() + 1
              else
                row = @getLineCount()

            @isUpdatingIndex++
            @insertLines(row, addedItemSpans)
            @isUpdatingIndex--

    @emitter.emit 'did-process-outline-mutation', mutation

  destroy: ->
    unless @destroyed
      @subscriptions.dispose()
      @outline.release()
      super()

  onWillProcessOutlineMutation: (callback) ->
    @emitter.on 'will-process-outline-mutation', callback

  onDidProcessOutlineMutation: (callback) ->
    @emitter.on 'did-process-outline-mutation', callback

  isVisible: (item) ->
    @editor?.isVisible(item) ? true

  isExpanded: (item) ->
    @editor?.isExpanded(item) ? true

  getHoistedItem: ->
    @editor?.getHoistedItem() ? @outline.root

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

    unless @isUpdatingIndex
      items = (each.item for each in lines)
      @isUpdatingItems++
      @outline.insertItemsBefore(items, insertBefore)
      @isUpdatingItems--

    super(row, lines)

  removeLines: (row, count) ->
    lines = []
    @iterateLines row, count, (each) =>
      @itemsToLinesMap.delete(each.item)
      lines.push(each)

    unless @isUpdatingIndex
      @isUpdatingItems++
      for each in lines
        @outline.removeItem(each.item)
      @isUpdatingItems--

    super(row, count)

  createLineFromText: (text) ->
    item = @outline.createItem()
    item.indent = @getHoistedItem().depth + 1
    outlineLine = new OutlineLine(this, item)
    outlineLine.setTextInRange(text, 0, 0)
    outlineLine
###