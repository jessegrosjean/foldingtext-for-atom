Mutation = require '../../core/mutation'
{CompositeDisposable} = require 'atom'
OutlineLine = require './outline-line'
Outline = require '../../core/outline'
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

    switch mutation.type
      when Mutation.BODT_TEXT_CHANGED
        item = mutation.target
        line = @getLineForItem(mutation.target)
        start = mutation.insertedTextLocation
        end = start + mutation.replacedText.length
        row = line.getRow()
        range = new Range([row, start], [row, end])
        text = item.bodyText.substr(start, mutation.insertedTextLength)

        @isUpdatingBufferFromOutline++
        @setTextInRange(text, range)
        @isUpdatingBufferFromOutline--

      when Mutation.CHILDREN_CHANGED
        parentLine = @getLineForItem(mutation.target)
        nextSiblingLine = @getLineForItem(mutation.nextSibling)

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

  getLineForItem: (item) ->
    @itemsToLinesMap.get(item)

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

module.exports = OutlineBuffer