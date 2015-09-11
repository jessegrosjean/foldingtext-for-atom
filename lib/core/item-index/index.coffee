{CompositeDisposable} = require 'atom'
LineIndex = require '../line-index'
ItemSpan = require './item-span'
Mutation = require '../mutation'
assert = require 'assert'
Item = require '../item'

class ItemIndex extends LineIndex

  constructor: (@hoistedItem, @editor) ->
    super()
    @isUpdatingIndex = 0
    @isUpdatingItems = 0
    @setHoistedItem(@hoistedItem)

  destroy: ->
    @subscriptions.dispose()
    super()

  ###
  Section: Events
  ###

  onWillProcessOutlineMutation: (callback) ->
    @_getEmitter().on 'will-process-outline-mutation', callback

  onDidProcessOutlineMutation: (callback) ->
    @emitter.on 'did-process-outline-mutation', callback

  ###
  Section: Hoisted Item
  ###

  getHoistedItem: ->
    @hoistedItem

  setHoistedItem: (@hoistedItem) ->
    @outline = @hoistedItem?.outline
    @isUpdatingIndex++
    @removeSpans(0, @getSpanCount())
    @subscriptions?.dispose()
    @subscriptions = new CompositeDisposable
    @itemsToItemSpansMap = new Map
    if @hoistedItem
      @subscriptions.add @outline.onDidChange @outlineDidChange.bind(this)
      @subscriptions.add @outline.onDidDestroy => @destroy()
      assert(@hoistedItem.isInOutline)
      itemSpans = (new ItemSpan(each) for each in @hoistedItem.descendants when @isVisible(each))
      @insertSpans(0, itemSpans)
    @isUpdatingIndex--

  outlineDidChange: (mutation) ->
    if @isUpdatingItems
      return

    @emitter?.emit 'will-process-outline-mutation', mutation
    @isUpdatingIndex++
    target = mutation.target
    switch mutation.type
      when Mutation.BODT_TEXT_CHANGED
        if itemSpan = @getItemSpanForItem(target)
          localLocation = mutation.insertedTextLocation
          insertedString = target.bodyText.substr(localLocation, mutation.insertedTextLength)
          location = itemSpan.getLocation() + localLocation
          @replaceRange(location, mutation.replacedText.length, insertedString)

      when Mutation.CHILDREN_CHANGED
        if mutation.removedItems.length
          @_outlineDidRemoveItems(target, mutation.getFlattendedRemovedItems())
        if mutation.addedItems.length
          @_outlineDidAddItems(target, mutation.addedItems)
    @isUpdatingIndex--
    @emitter.emit 'did-process-outline-mutation', mutation

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
    if target isnt @hoistedItem
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

  getItemRange: (location, length) ->
    start = @getSpanInfoAtLocation(location, true)
    end = @getSpanInfoAtLocation(location + length, true)
    {} =
      startItem: start.span.item
      startOffset: start.location
      endItem: end.span.item
      endOffset: end.location

  getRangeFromItemRange: (startItem, startOffset, endItem, endOffset) ->
    unless startItem instanceof Item
      {startItem, startOffset, endItem, endOffset} = startItem

    visibleStartItem = startItem
    while visibleStartItem and not @isVisible(visibleStartItem)
      visibleStartItem = visibleStartItem.previousItem
    if startItem isnt visibleStartItem
      startItem = visibleStartItem
      unless startItem
        return location: 0, length: 0
      startOffset = 0

    visibleEndItem = endItem
    while visibleEndItem and not @isVisible(visibleEndItem)
      visibleEndItem = visibleEndItem.previousItem
    if endItem isnt visibleEndItem
      endItem = visibleEndItem
      unless endItem
        return location: 0, length: 0
      endOffset = 0

    startOffset ?= 0
    start = @getItemSpanForItem(startItem).getLocation() + startOffset
    if endItem
      endOffset ?= 0
      end = @getItemSpanForItem(endItem).getLocation() + endOffset
    else
      end = start

    {} =
      location: start
      length: end - start

  replaceRange: (location, length, string) ->
    super(location, length, string)

  ###
  Character attributes
  ###

  getAttributesAtIndex: (location, effectiveRange, longestEffectiveRange) ->
    start = @getSpanInfoAtLocation(location, true)
    attributes = start.span.item.getBodyTextAttributesAtIndex(start.location, effectiveRange, longestEffectiveRange)
    if effectiveRange
      effectiveRange.location += start.spanLocation
    if longestEffectiveRange
      longestEffectiveRange.location += start.spanLocation
    attributes

  getBodyTextAttributeAtIndex: (attribute, location, effectiveRange, longestEffectiveRange) ->
    start = @getSpanInfoAtLocation(location, true)
    attribute = start.span.item.getBodyTextAttributesAtIndex(attribute, start.location, effectiveRange, longestEffectiveRange)
    if effectiveRange
      effectiveRange.location += start.spanLocation
    if longestEffectiveRange
      longestEffectiveRange.location += start.spanLocation
    attribute

  setAttributesInRange: (attributes, location, length) ->

  addAttributeInRange: (attribute, value, location, length) ->

  addAttributesInRange: (attributes, location, length) ->

  removeAttributeInRange: (attribute, location, length) ->

  ###
  Section: Item Spans
  ###

  createSpan: (text) ->
    new ItemSpan(@outline.createItem(text))

  createSpanForItem: (item) ->
    new ItemSpan(item)

  getItemSpanForItem: (item) ->
    @itemsToItemSpansMap.get(item)

  insertSpans: (spanIndex, itemSpans) ->
    insertBefore = @getSpan(spanIndex)?.item or @hoistedItem.nextSibling

    for each in itemSpans
      @itemsToItemSpansMap.set(each.item, each)

    unless @isUpdatingIndex
      items = (each.item for each in itemSpans)
      @isUpdatingItems++
      @outline.insertItemsBefore(items, insertBefore)
      @isUpdatingItems--

    super(spanIndex, itemSpans)

  removeSpans: (spanIndex, removeCount) ->
    lineSpans = []
    @iterateLines spanIndex, removeCount, (each) =>
      @itemsToItemSpansMap.delete(each.item)
      lineSpans.push(each)

    unless @isUpdatingIndex
      @isUpdatingItems++
      for each in lineSpans
        @outline.removeItem(each.item)
      @isUpdatingItems--

    super(spanIndex, removeCount)

module.exports = ItemIndex