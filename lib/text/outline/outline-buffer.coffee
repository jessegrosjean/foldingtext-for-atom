Mutation = require '../../core/mutation'
{CompositeDisposable} = require 'atom'
OutlineLine = require './outline-line'
Outline = require '../../core/outline'
shortid = require '../../core/shortid'
{replace} = require '../helpers'
Buffer = require '../buffer'
Range = require '../range'

class OutlineBuffer extends Buffer

  outline: null
  hoistedItem: null
  isUpdatingOutlineFromBuffer: 0
  isUpdatingBufferFromOutline: 0
  itemsToLinesMap: new Map

  constructor: (outline) ->
    super()
    @id = shortid()
    @subscriptions = new CompositeDisposable
    @outline = outline or Outline.buildOutlineSync()
    @subscribeToOutline()
    @setHoistedItem(@outline.root)

  subscribeToOutline: ->
    @outline.retain()
    @subscriptions.add @outline.onDidChange @outlineDidChange.bind(this)
    @subscriptions.add @outline.onDidDestroy => @destroy()

  outlineDidChange: (mutation) ->
    if @isUpdatingOutlineFromBuffer
      return

    target = mutation.target

    switch mutation.type
      when Mutation.BODT_TEXT_CHANGED
        if line = @getLineForItem(target)
          start = mutation.insertedTextLocation
          end = start + mutation.replacedText.length
          row = line.getRow()
          range = new Range([row, start], [row, end])
          text = target.bodyText.substr(start, mutation.insertedTextLength)

          @isUpdatingBufferFromOutline++
          @setTextInRange(text, range)
          @isUpdatingBufferFromOutline--

      when Mutation.CHILDREN_CHANGED
        parentLine = @getLineForItem(target)
        nextSiblingLine = @getLineForItem(mutation.nextSibling)

        unless target is @getHoistedItem() or parentLine
          return

        # Remove lines
        if mutation.removedItems.length
          removeStart = undefined
          removeCount = 0

          for each in mutation.getFlattendedRemovedItems()
            if line = @getLineForItem(each)
              removeStart ?= line.getRow()
              removeCount++
          if removeCount
            @isUpdatingBufferFromOutline++
            @removeLines(removeStart, removeCount)
            @isUpdatingBufferFromOutline--

        # Insert lines
        if mutation.addedItems.length
          addedLines = []
          for each in mutation.getFlattendedAddedItems()
            addedLines.push(new OutlineLine(this, each))

          @isUpdatingBufferFromOutline++
          if parentLine
            @insertLines(parentLine.getRow() + 1, addedLines)
          else
            @insertLines(nextSiblingLine?.getRow() ? @getLineCount(), addedLines)
          @isUpdatingBufferFromOutline--

  destroy: ->
    unless @destroyed
      @subscriptions.dispose()
      @outline.release
      super()

  ###
  Section: Hoisted Item
  ###

  getHoistedItem: ->
    @hoistedItem or @outline.root

  setHoistedItem: (item) ->
    @hoistedItem = item

    @isUpdatingBufferFromOutline++
    @removeLines(0, @getLineCount())
    @isUpdatingBufferFromOutline--

    newLines = []
    for each in @getHoistedItem().descendants
      newLines.push(new OutlineLine(this, each))
    @isUpdatingBufferFromOutline++
    @insertLines(0, newLines)
    @isUpdatingBufferFromOutline--

  ###
  Section: Expanding Items
  ###

  isExpanded: (item) ->
    return item and @getItemBufferState(item).expanded

  isCollapsed: (item) ->
    return item and not @getItemBufferState(item).expanded

  setExpanded: (items) ->
    @_setExpandedState items, true

  setCollapsed: (items) ->
    @_setExpandedState items, false

  _setExpandedState: (items, expanded) ->
    if not _.isArray(items)
      items = [items]

    for each in items
      if @isExpanded(each) isnt expanded
        @getItemBufferState(each).expanded = expanded

        if expanded
          # Insert lines for visible descendents of each
        else
          # Remove lines for descendents of each

  ###
  Section: Matched Items
  ###

  isMatched: (item) ->
    return item and @getItemBufferState(item).matched

  isMatchedAncestor: (item) ->
    return item and @getItemBufferState(item).matchedAncestor

  setQuery: (query) ->
    # Remove old state
    @iterateLines 0, @getLineCount(), (line) ->
      item = line.item
      itemState = @getItemBufferState(item)
      itemState.matched = false
      itemState.matchedAncestor = false

    # Remove old lines
    @isUpdatingBufferFromOutline++
    @removeLines(0, @getLineCount())
    @isUpdatingBufferFromOutline--

    if query
      # Set matched state for each result
      # Add lines for all expanded items below hoisted item that match query
    else
      # Add lines for all expanded items below hoisted item

  ###
  Section: Item State
  ###

  getLineForItem: (item) ->
    @itemsToLinesMap.get(item)

  getItemBufferState: (item) ->
    if item
      key = @id + '-buffer-state'
      unless state = item.getUserData(key)
        state = new ItemBufferState
        item.setUserData key, state
      state

  ###
  Section: Line Overrides
  ###

  insertLines: (row, lines) ->
    insertBefore = @getLine(row)?.item or @getHoistedItem().nextSibling

    for each in lines
      @itemsToLinesMap.set(each.item, each)

    unless @isUpdatingBufferFromOutline
      items = (each.item for each in lines)
      @isUpdatingOutlineFromBuffer++
      @outline.insertItemsBefore(items, insertBefore)
      @isUpdatingOutlineFromBuffer--

    super(row, lines)

  removeLines: (row, count) ->
    lines = []
    @iterateLines row, count, (each) =>
      @itemsToLinesMap.delete(each)
      lines.push(each)

    unless @isUpdatingBufferFromOutline
      @isUpdatingOutlineFromBuffer++
      for each in lines
        @outline.removeItem(each.item)
      @isUpdatingOutlineFromBuffer--

    super(row, count)

  setTextInRange: (newText, range) ->
    super(newText, range)

  ###
  Section: Text Line Overrides
  ###

  createLineFromText: (text) ->
    item = @outline.createItem()
    item.indent = @getHoistedItem().depth + 1
    outlineLine = new OutlineLine(this, item)
    outlineLine.setTextInRange(text, 0, 0)
    outlineLine

class ItemBufferState
  constructor: ->
    @marked = false
    @selected = false
    @expanded = false
    @matched = false
    @matchedAncestor = false

module.exports = OutlineBuffer