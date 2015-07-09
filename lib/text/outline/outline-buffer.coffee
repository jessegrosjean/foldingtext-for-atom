{Emitter, CompositeDisposable} = require 'atom'
Mutation = require '../../core/mutation'
OutlineLine = require './outline-line'
Outline = require '../../core/outline'
{replace} = require '../helpers'
Buffer = require '../buffer'
Range = require '../range'

class OutlineBuffer extends Buffer

  hoistedItem: null
  isUpdatingOutlineFromBuffer: 0
  isUpdatingBufferFromOutline: 0
  itemsToLinesMap: new Map

  constructor: (outline) ->
    super()
    @emitter = new Emitter()
    @subscriptions = new CompositeDisposable
    @outline = outline or Outline.buildOutlineSync()
    @hoistedItem = @outline.root
    @subscribeToOutline()

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
      @destroyed = true
      @subscriptions.dispose()
      @outline.release
      @emitter.emit 'did-destroy'

  ###
  Section: Lines
  ###

  getLineForItem: (item) ->
    @itemsToLinesMap.get(item)

  insertLines: (row, lines) ->
    insertBefore = @getLine(row)?.item

    super(row, lines)

    for each in lines
      @itemsToLinesMap.set(each.item, each)

    unless @isUpdatingBufferFromOutline
      items = (each.item for each in lines)
      @isUpdatingOutlineFromBuffer++
      @outline.insertItemsBefore(items, insertBefore)
      @isUpdatingOutlineFromBuffer--

  removeLines: (row, count) ->
    lines = []
    @iterateLines row, count, (each) =>
      @itemsToLinesMap.delete(each)
      lines.push(each)
    super(row, count)

    unless @isUpdatingBufferFromOutline
      @isUpdatingOutlineFromBuffer++
      for each in lines
        @outline.removeItem(each.item)
      @isUpdatingOutlineFromBuffer--

  setTextInRange: (newText, range) ->
    super(newText, range)

  ###
  Section: Text Line Overrides
  ###

  createLineFromText: (text) ->
    item = @outline.createItem()
    item.indent = @hoistedItem.depth + 1
    outlineLine = new OutlineLine(this, item)
    outlineLine.setTextInRange(text, 0, 0)
    outlineLine

module.exports = OutlineBuffer