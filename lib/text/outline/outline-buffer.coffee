Mutation = require '../../core/mutation'
{repeat, replace} = require '../helpers'
{CompositeDisposable} = require 'atom'
OutlineLine = require './outline-line'
Outline = require '../../core/outline'
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

    target = mutation.target

    switch mutation.type
      when Mutation.ATTRIBUTE_CHANGED
        if mutation.attributeName is 'indent'
          if line = @getLineForItem(target)
            oldIndent = mutation.attributeOldValue or 1
            newIndent = target.indent
            row = line.getRow()
            range = new Range([row, 0], [row, oldIndent - 1])
            delta = newIndent - oldIndent
            @isUpdatingBuffer++
            @setTextInRange(repeat('\t', delta), range)
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
        parentLine = @getLineForItem(target)

        unless target is @getHoistedItem() or parentLine
          return

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
              row = 0

          @isUpdatingBuffer++
          @insertLines(row, addedLines)
          @isUpdatingBuffer--

  destroy: ->
    unless @destroyed
      @subscriptions.dispose()
      @outline.release()
      super()

  ###
  Section: Outline Editor Cover
  ###

  isVisible: (item) ->
    @outlineEditor?.isVisible(item) or true

  getHoistedItem: ->
    @outlineEditor?.getHoistedItem() or @outline.root

  ###
  Section: Lines
  ###

  getLineForItem: (item) ->
    @itemsToLinesMap.get(item)

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
      @itemsToLinesMap.delete(each)
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