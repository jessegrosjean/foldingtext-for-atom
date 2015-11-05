{CompositeDisposable} = require 'atom'
LineBuffer = require '../line-buffer'
ItemRange = require '../item-range'
ItemSpan = require './item-span'
Mutation = require '../mutation'
Outline = require '../outline'
_ = require 'underscore-plus'
assert = require 'assert'
Item = require '../item'

class ItemBuffer extends LineBuffer

  constructor: (@outline, @editor) ->
    super()
    @outline ?= new Outline
    @isUpdatingIndex = 0
    @isUpdatingItems = 0
    @hoistedItem = null

    @subscriptions = new CompositeDisposable
    @subscriptions.add @outline.onDidChange @outlineDidChange.bind(this)
    @subscriptions.add @outline.onDidDestroy => @destroy()

  destroy: ->
    @subscriptions.dispose()
    super()

  beginChanges: (changeEvent) ->
    unless @isChanging()
      @outline.beginChanges()
    super(changeEvent)

  endChanges: ->
    super()
    unless @isChanging()
      @outline.endChanges()

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
    assert(@hoistedItem.outline is @outline)

    @beginChanges()
    @isUpdatingIndex++
    @removeSpans(0, @getSpanCount())
    @itemsToItemSpansMap = new Map
    if @hoistedItem
      assert(@hoistedItem.isInOutline)
      itemSpans = (new ItemSpan(each) for each in @hoistedItem.descendants when @isVisible(each))
      @insertSpans(0, itemSpans)
    @isUpdatingIndex--
    @endChanges()

  outlineDidChange: (mutation) ->
    if @isUpdatingItems
      return

    @emitter?.emit 'will-process-outline-mutation', mutation
    @isUpdatingIndex++
    target = mutation.target
    switch mutation.type
      when Mutation.BODY_CHANGED
        if itemSpan = @getItemSpanForItem(target)
          localLocation = mutation.insertedTextLocation
          insertedString = target.bodyString.substr(localLocation, mutation.insertedTextLength)
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
    if start
      new ItemRange(start.span.item, start.location, end.span.item, end.location)
    else
      null

  getRangeFromItemRange: (startItem, startOffset, endItem, endOffset, reveal=false) ->
    unless startItem instanceof Item
      {startItem, startOffset, endItem, endOffset} = startItem

    if reveal
      @editor?.makeVisible(startItem)
      @editor?.makeVisible(endItem)

    visibleStartItem = startItem
    while visibleStartItem and not @isVisible(visibleStartItem)
      visibleStartItem = visibleStartItem.previousItem
    if startItem isnt visibleStartItem
      startItem = visibleStartItem
      unless startItem
        return location: 0, length: 0
      startOffset = startItem.bodyString.length

    visibleEndItem = endItem
    while visibleEndItem and not @isVisible(visibleEndItem)
      visibleEndItem = visibleEndItem.previousItem
    if endItem isnt visibleEndItem
      endItem = visibleEndItem
      unless endItem
        return location: 0, length: 0
      endOffset = endItem.bodyString.length

    unless startItem
      return location: 0, length: 0

    startOffset ?= 0
    if startOffset is -1
      startOffset = startItem.bodyString.length
    if startOffset > startItem.bodyString.length
      startOffset = startItem.bodyString.length

    start = @getItemSpanForItem(startItem).getLocation() + startOffset
    if endItem
      endOffset ?= 0
      if endOffset is -1
        endOffset = endItem.bodyString.length
      if endOffset > endItem.bodyString.length
        endOffset = endItem.bodyString.length
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

  getAttributedString: (spanIndex, count) ->
    runSpans = []
    for each in @getSpans(spanIndex, count)
      spanString = each.getString()

      item = each.item
      itemAttributes =
        id: item.id
        parentID: item.parent.id
        attributes: item.attributes

      body = item.bodyHighlightedAttributedString
      bodyRunBuffer = body.runBuffer
      if bodyRunBuffer
        body.runBuffer.iterateRuns 0, body.runBuffer.getRunCount(), (run) ->
          attributes = _.clone(run.attributes)
          attributes.item = itemAttributes
          runSpans.push
            string: run.string
            attributes: attributes
        if body.length isnt spanString.length
          runSpans.push
            string: '\n'
            attributes: (item: itemAttributes)
      else
        runSpans.push
          string: spanString
          attributes: (item: itemAttributes)
    runSpans

  getAttributesAtIndex: (location, effectiveRange, longestEffectiveRange) ->
    start = @getSpanInfoAtLocation(location, true)
    attributes = start.span.item.getBodyAttributesAtIndex(start.location, effectiveRange, longestEffectiveRange)
    if effectiveRange
      effectiveRange.location += start.spanLocation
    if longestEffectiveRange
      longestEffectiveRange.location += start.spanLocation
    attributes

  getBodyAttributeAtIndex: (attribute, location, effectiveRange, longestEffectiveRange) ->
    start = @getSpanInfoAtLocation(location, true)
    attribute = start.span.item.getBodyAttributesAtIndex(attribute, start.location, effectiveRange, longestEffectiveRange)
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
    item = @outline.createItem(text)
    item.indent = @hoistedItem.depth + 1
    new ItemSpan(item)

  createSpanForItem: (item) ->
    new ItemSpan(item)

  getItemSpanForItem: (item) ->
    @itemsToItemSpansMap.get(item)

  insertSpans: (spanIndex, itemSpans) ->
    insertBefore = @getSpan(spanIndex)?.item or @hoistedItem.nextSibling
    hoistedDepth = @getHoistedItem().depth

    for each in itemSpans
      assert(each.item.depth > hoistedDepth, 'Span item depth must be greater then hoisted item depth')
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

module.exports = ItemBuffer
