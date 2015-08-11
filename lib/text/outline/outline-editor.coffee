OutlineBuffer = require './outline-buffer'
{CompositeDisposable} = require 'atom'
Outline = require '../../core/outline'
shortid = require '../../core/shortid'
OutlineLine = require './outline-line'
Item = require '../../core/item'
_ = require 'underscore-plus'
Range = require '../range'
assert = require 'assert'

class OutlineEditor

  constructor: (outline, @nativeEditor) ->
    @id = shortid()
    @isUpdatingNativeBuffer = 0
    @isUpdatingOutlineBuffer = 0
    @subscriptions = new CompositeDisposable
    @outlineBuffer = new OutlineBuffer(outline, this)
    @nativeEditor ?= new NativeEditor

    @subscriptions.add @outlineBuffer.onDidChange (e) =>
      if not @isUpdatingOutlineBuffer
        range = e.oldCharacterRange
        nsrange = location: range.start, length: range.end - range.start
        @isUpdatingNativeBuffer++
        @nativeEditor.nativeTextBufferReplaceCharactersInRangeWithString(nsrange, e.newText)
        @isUpdatingNativeBuffer--
      assert(@nativeEditor.nativeTextContent is @outlineBuffer.getText(), 'Text Buffers are Equal')

    @setHoistedItem(@outlineBuffer.outline.root)

  nativeTextBufferDidReplaceCharactersInRangeWithString: (nsrange, string) ->
    if not @isUpdatingNativeBuffer
      range = @outlineBuffer.getRangeFromCharacterRange(nsrange.location, nsrange.location + nsrange.length)
      @isUpdatingOutlineBuffer++
      @outlineBuffer.setTextInRange(string, range)
      @isUpdatingOutlineBuffer--

  destroy: ->
    unless @destroyed
      @outlineBuffer.destroy()
      @subscriptions.dispose()
      @destroyed = true

  ###
  Section: Hoisted Item
  ###

  hoist: ->
    if item = @getSelectedItems()[0]
      @setHoistedItem(item)

  unhoist: ->
    @setHoistedItem(@outlineBuffer.outline.root)

  getHoistedItem: ->
    @hoistedItem or @outline.root

  setHoistedItem: (item) ->
    @hoistedItem = item

    @outlineBuffer.isUpdatingBuffer++
    @outlineBuffer.removeLines(0, @outlineBuffer.getLineCount())
    @outlineBuffer.isUpdatingBuffer--

    newLines = []
    @_gatherLinesForVisibleDescendents(@getHoistedItem(), newLines)
    @outlineBuffer.isUpdatingBuffer++
    @outlineBuffer.insertLines(0, newLines)
    @outlineBuffer.isUpdatingBuffer--

  _gatherLinesForVisibleDescendents: (item, lines) ->
    each = @getFirstVisibleChild(item)
    while each
      lines.push(new OutlineLine(@outlineBuffer, each))
      @_gatherLinesForVisibleDescendents(each, lines)
      each = @getNextVisibleSibling(each)

  ###
  Section: Matched Items
  ###

  isMatched: (item) ->
    return item and @getItemEditorState(item).matched

  isMatchedAncestor: (item) ->
    return item and @getItemEditorState(item).matchedAncestor

  setQuery: (query) ->
    # Remove old state
    @iterateLines 0, @getLineCount(), (line) ->
      item = line.item
      itemState = @getItemEditorState(item)
      itemState.matched = false
      itemState.matchedAncestor = false

    # Remove old lines
    @outlineBuffer.isUpdatingBuffer++
    @removeLines(0, @getLineCount())
    @outlineBuffer.isUpdatingBuffer--

    if query
      # Set matched state for each result
      # Add lines for all expanded items below hoisted item that match query
    else
      # Add lines for all expanded items below hoisted item

  ###
  Section: Expand & Collapse
  ###

  isExpanded: (item) ->
    return item and @getItemEditorState(item).expanded

  isCollapsed: (item) ->
    return item and not @getItemEditorState(item).expanded

  setExpanded: (items) ->
    @_setExpandedState items, true

  setCollapsed: (items) ->
    @_setExpandedState items, false

  toggleExpanded: -> (items) ->
    @_setExpandedState item, undefined

  expandAll: ->
    @setExpanded(@getHoistedItem().descendants)

  collapseAll: ->
    @setCollapsed(@getHoistedItem().descendants)

  expandToIndentLevel: (level) ->
    collapseItems = []
    expandItems = []

    gather = (item, level) ->
      if level >= 0
        expandItems.push(item)
      else
        collapseItems.push(item)
      for each in item.children
        gather(each, level - 1)

    gather(@getHoistedItem(), level)
    @setCollapsed(collapseItems)
    @setExpanded(expandItems)

  _setExpandedState: (items, expanded) ->
    items ?= @getSelectedItems()
    if not _.isArray(items)
      items = [items]

    selectedItemRange = @getSelectedItemRange()

    @outlineBuffer.isUpdatingBuffer++
    if expanded
      # for better animations
      for each in items
        if not @isVisible(each)
          @getItemEditorState(each).expanded = expanded
      for each in items
        if @isExpanded(each) isnt expanded
          @getItemEditorState(each).expanded = expanded
          @_insertVisibleDescendantLines(each)
    else
      # for better animations
      for each in Item.getCommonAncestors(items)
        if @isExpanded(each) isnt expanded
          @getItemEditorState(each).expanded = expanded
          @_removeDescendantLines(each)
      for each in items
        @getItemEditorState(each).expanded = expanded
    @outlineBuffer.isUpdatingBuffer--

    @setSelectedItemRange(selectedItemRange)

  _insertVisibleDescendantLines: (item) ->
    if itemLine = @outlineBuffer.getLineForItem(item)
      if each = @getFirstVisibleChild(item)
        insertLines = []
        end = @getNextVisibleItem(@getLastVisibleDescendantOrSelf(item))
        while each isnt end
          insertLines.push(new OutlineLine(@outlineBuffer, each))
          each = @getNextVisibleItem(each)
        @outlineBuffer.insertLines(itemLine.getRow() + 1, insertLines)

  _removeDescendantLines: (item) ->
    if itemLine = @outlineBuffer.getLineForItem(item)
      start = itemLine.getRow() + 1
      end = start
      while item.contains(@outlineBuffer.getLine(end)?.item)
        end++
      @outlineBuffer.removeLines(start, end - start)

  ###
  Section: Item Visibility
  ###

  # Public: Determine if an {Item} is visible. An item is visible if it
  # descends from the current hoisted item, and it isn't filtered, and all
  # ancestors up to hoisted node are expanded.
  #
  # - `item` {Item} to test.
  # - `hoistedItem` (optional) Hoisted item {Item} case to consider.
  #
  # Returns {Boolean} indicating if item is visible.
  isVisible: (item, hoistedItem) ->
    parent = item?.parent
    hoistedItem = hoistedItem or @getHoistedItem()
    while parent isnt hoistedItem
      return false unless @isExpanded(parent)
      parent = parent.parent
    return true

  # Public: Returns first visible {Item} in editor.
  #
  # - `hoistedItem` (optional) Hoisted item {Item} case to consider.
  getFirstVisibleItem: (hoistedItem) ->
    hoistedItem = hoistedItem or @getHoistedItem()
    @getNextVisibleItem(hoistedItem, hoistedItem)

  # Public: Returns last visible {Item} in editor.
  #
  # - `hoistedItem` (optional) Hoisted item {Item} case to consider.
  getLastVisibleItem: (hoistedItem) ->
    hoistedItem = hoistedItem or @getHoistedItem()
    last = hoistedItem.lastDescendantOrSelf
    if @isVisible(last, hoistedItem)
      last
    else
      @getPreviousVisibleItem(last, hoistedItem)

  # Public: Returns previous visible sibling {Item} relative to given item.
  #
  # - `item` {Item}
  # - `hoistedItem` (optional) Hoisted item {Item} case to consider.
  getPreviousVisibleSibling: (item, hoistedItem) ->
    return null unless item

    item = item.previousSibling
    while item
      if @isVisible item, hoistedItem
        return item
      item = item.previousSibling

  # Public: Returns next visible sibling {Item} relative to given item.
  #
  # - `item` {Item}
  # - `hoistedItem` (optional) Hoisted item {Item} case to consider.
  getNextVisibleSibling: (item, hoistedItem) ->
    return null unless item

    item = item.nextSibling
    while item
      if @isVisible item, hoistedItem
        return item
      item = item.nextSibling

  # Public: Returns next visible {Item} relative to given item.
  #
  # - `item` {Item}
  # - `hoistedItem` (optional) Hoisted item {Item} case to consider.
  getNextVisibleItem: (item, hoistedItem) ->
    return null unless item

    item = item.nextItem
    while item
      if @isVisible item, hoistedItem
        return item
      item = item.nextItem

  # Public: Returns previous visible {Item} relative to given item.
  #
  # - `item` {Item}
  # - `hoistedItem` (optional) Hoisted item {Item} case to consider.
  getPreviousVisibleItem: (item, hoistedItem) ->
    return null unless item

    item = item.previousItem
    while item
      if @isVisible item, hoistedItem
        return item
      item = item.previousItem

  # Public: Returns first visible child {Item} relative to given item.
  #
  # - `item` {Item}
  # - `hoistedItem` (optional) Hoisted item {Item} case to consider.
  getFirstVisibleChild: (item, hoistedItem) ->
    return null unless item

    firstChild = item.firstChild
    if @isVisible firstChild, hoistedItem
      return firstChild
    @getNextVisibleSibling firstChild, hoistedItem

  # Public: Returns last visible child {Item} relative to given item.
  #
  # - `item` {Item}
  # - `hoistedItem` (optional) Hoisted item {Item} case to consider.
  getLastVisibleChild: (item, hoistedItem) ->
    return null unless item

    lastChild = item.lastChild
    if @isVisible lastChild, hoistedItem
      return lastChild
    @getPreviousVisibleSibling lastChild, hoistedItem

  getLastVisibleDescendantOrSelf: (item, hoistedItem) ->
    return null unless item

    lastChild = @getLastVisibleChild item, hoistedItem
    if lastChild
      @getLastVisibleDescendantOrSelf lastChild, hoistedItem
    else
      item

  # Public: Returns previous visible branch {Item} relative to given item.
  #
  # - `item` {Item}
  # - `hoistedItem` (optional) Hoisted item {Item} case to consider.
  getPreviousVisibleBranch: (item, hoistedItem) ->
    return null unless item

    previousBranch = item?.previousBranch
    if @isVisible previousBranch, hoistedItem
      previousBranch
    else
      @getPreviousVisibleBranch(previousBranch)

  # Public: Returns next visible branch {Item} relative to given item.
  #
  # - `item` {Item}
  # - `hoistedItem` (optional) Hoisted item {Item} case to consider.
  getNextVisibleBranch: (item, hoistedItem) ->
    return null unless item

    nextBranch = item.nextBranch
    if @isVisible nextBranch, hoistedItem
      nextBranch
    else
      @getNextVisibleBranch nextBranch, hoistedItem

  ###
  Section: Selection
  ###

  # Public: Returns the selection {Range}.
  getSelectedRange: ->
    @getSelectedRanges()[0]

  getSelectedRanges: ->
    ranges = []
    #nsranges = @nativeTextBuffer.selectedRanges()
    nsranges = [@nativeEditor.nativeSelectedRange]
    for each in nsranges
      ranges.push @outlineBuffer.getRangeFromCharacterRange(each.location, each.location + each.length)
    ranges

  getSelectedItems: ->
    selectedItems = []
    for each in @getSelectedRanges()
      rangeItems = (each.item for each in @outlineBuffer.getLinesInRange(each))
      last = selectedItems[selectedItems.length - 1]
      while rangeItems.length > 0 and rangeItems[0] is last
        rangeItems.shift()
      Array.prototype.push.apply(selectedItems, rangeItems)
    selectedItems

  getSelectedItemRange: ->
    @outlineBuffer.getItemRangeFromRange(@getSelectedRange())

  # Public: Sets the selection.
  #
  # - `range` {Range}
  setSelectedRange: (range) ->
    @setSelectedRanges([range])

  setSelectedRanges: (ranges) ->
    nsranges = []
    ranges = (@outlineBuffer.clipRange(each) for each in ranges)
    for each in ranges
      characterRange = @outlineBuffer.getCharacterRangeFromRange(each)
      nsranges.push
        location: characterRange.start
        length: characterRange.end - characterRange.start
    #@nativeEditor.setSelectedRanges(nsranges)
    @nativeEditor.nativeSelectedRange = nsranges[0]

  setSelectedItemRange: (startItem, startOffset, endItem, endOffset) ->
    @setSelectedRange(@outlineBuffer.getRangeFromItemRange(startItem, startOffset, endItem, endOffset))

  ###
  Section: Insert
  ###

  insertNewline: ->
    selectionRange = @selection
    if selectionRange.isTextMode
      if not selectionRange.isCollapsed
        @delete()
        selectionRange = @selection

      focusItem = selectionRange.focusItem
      focusOffset = selectionRange.focusOffset

      if focusOffset is 0
        @insertItem('', true)
        @moveSelectionRange(focusItem, 0)
      else
        splitText = focusItem.getAttributedBodyTextSubstring(focusOffset, -1)
        undoManager = @outline.undoManager
        undoManager.beginUndoGrouping()
        focusItem.replaceBodyTextInRange('', focusOffset, -1)
        @insertItem(splitText)
        undoManager.endUndoGrouping()
    else
      @insertItem()

  insertNewlineAbove: (text) ->
    @insertItem(text, true)

  insertNewlineBelow: (text) ->
    @insertItem(text)

  # Public: Insert item at current selection.
  #
  # - `text` Text {String} or {AttributedString} for new item.
  #
  # Returns the new {Item}.
  insertItem: (text, above=false) ->
    text ?= ''
    selectedItems = @selection.items
    insertBefore
    parent

    if above
      selectedItem = selectedItems[0]
      if not selectedItem
        parent = @getHoistedItem()
        insertBefore = @getFirstVisibleChild parent
      else
        parent = selectedItem.parent
        insertBefore = selectedItem
    else
      selectedItem = selectedItems[selectedItems.length - 1]
      if not selectedItem
        parent = @getHoistedItem()
        insertBefore = @getFirstVisibleChild parent
      else if @isExpanded(selectedItem)
        parent = selectedItem
        insertBefore = @getFirstVisibleChild parent
      else
        parent = selectedItem.parent
        insertBefore = @getNextVisibleSibling selectedItem

    outline = parent.outline
    outlineEditorElement = @outlineEditorElement
    insertItem = outline.createItem(text)
    undoManager = outline.undoManager

    undoManager.beginUndoGrouping()
    parent.insertChildBefore(insertItem, insertBefore)
    undoManager.endUndoGrouping()

    undoManager.setActionName('Insert Item')
    @moveSelectionRange(insertItem, 0)

    insertItem

  ###
  Section: Move Lines
  ###

  moveLinesUp: (items) ->
    @_moveLinesInDirection(items, 'up')

  moveLinesDown: (items) ->
    @_moveLinesInDirection(items, 'down')

  moveLinesLeft: (items) ->
    @_moveLinesInDirection(items, 'left')

  moveLinesRight: (items) ->
    @_moveLinesInDirection(items, 'right')

  _moveLinesInDirection: (items, direction) ->
    items ?= @getSelectedItems()
    if items.length
      selectedItemRange = @getSelectedItemRange()
      minDepth = @getHoistedItem().depth + 1
      outline = @outlineBuffer.outline
      firstItem = items[0]
      endItem = items[items.length - 1]
      referenceItem = null
      depthDelta = 0

      switch direction
        when 'up'
          referenceItem = @getPreviousVisibleItem(firstItem)
          unless referenceItem
            return
        when 'down'
          unless nextVisibleItem = @getNextVisibleItem(endItem)
            return
          referenceItem = nextVisibleItem.nextItem
        when 'left'
          depthDelta = -1
          referenceItem = endItem.nextItem
        when 'right'
          depthDelta = 1
          referenceItem = endItem.nextItem

      outline.beginChanges()

      expandItems = []
      disposable = outline.onDidChange (mutation) ->
        if mutation.target.hasChildren and not (mutation.target in expandItems)
          expandItems.push mutation.target

      outline.removeItems(items)

      if depthDelta
        for each in items
          each.indent = Math.max(minDepth, each.indent + depthDelta)

      outline.insertItemsBefore(items, referenceItem)

      outline.endChanges =>
        @setExpanded(expandItems)
        disposable.dispose()

      @setSelectedItemRange(selectedItemRange)

  ###
  Section: Move Branches
  ###

  moveBranchesUp: ->
    @_moveBranchesInDirection('up')

  moveBranchesDown: ->
    @_moveBranchesInDirection('down')

  moveBranchesLeft: ->
    @_moveBranchesInDirection('left')

  moveBranchesRight: ->
    @_moveBranchesInDirection('right')

  _moveBranchesInDirection: (direction) ->
    selectedItems = Item.getCommonAncestors(@getSelectedItems())
    if selectedItems.length > 0
      startItem = selectedItems[0]
      newNextSibling
      newParent

      if direction is 'up'
        newNextSibling = @getPreviousVisibleSibling(startItem)
        if newNextSibling
          newParent = newNextSibling.parent
      else if direction is 'down'
        endItem = selectedItems[selectedItems.length - 1]
        newPreviousSibling = @getNextVisibleSibling(endItem)
        if newPreviousSibling
          newParent = newPreviousSibling.parent
          newNextSibling = @getNextVisibleSibling(newPreviousSibling)
      else if direction is 'left'
        startItemParent = startItem.parent
        if startItemParent isnt @getHoistedItem()
          newParent = startItemParent.parent
          newNextSibling = @getNextVisibleSibling(startItemParent)
          while newNextSibling and newNextSibling in selectedItems
            newNextSibling = @getNextVisibleSibling(newNextSibling)
      else if direction is 'right'
        newParent = @getPreviousVisibleSibling(startItem)

      if newParent
        @moveBranches(selectedItems, newParent, newNextSibling)

  promoteChildItems: ->
    selectedItems = Item.getCommonAncestors(@getSelectedItems())
    if selectedItems.length > 0
      undoManager = @outline.undoManager
      undoManager.beginUndoGrouping()
      for each in selectedItems
        @moveBranches(each.children, each.parent, each.nextSibling)
      undoManager.endUndoGrouping()
      undoManager.setActionName('Promote Children')

  demoteTrailingSiblingItems: ->
    selectedItems = Item.getCommonAncestors(@getSelectedItems())
    item = selectedItems[0]

    if item
      trailingSiblings = []
      each = item.nextSibling

      while each
        trailingSiblings.push(each)
        each = each.nextSibling

      if trailingSiblings.length > 0
        @moveBranches(trailingSiblings, item, null)
        @outline.undoManager.setActionName('Demote Siblings')

  groupItems: ->
    selectedItems = Item.getCommonAncestors(@getSelectedItems())
    if selectedItems.length > 0
      first = selectedItems[0]
      group = @outline.createItem ''

      undoManager = @outline.undoManager
      undoManager.beginUndoGrouping()

      first.parent.insertChildBefore group, first
      @moveSelectionRange group, 0
      @moveBranches selectedItems, group

      undoManager.endUndoGrouping()
      undoManager.setActionName('Group Items')

  duplicateItems: ->
    selectedItems = Item.getCommonAncestors(@getSelectedItems())
    if selectedItems.length > 0
      anchorItem = @selection.anchorItem
      nextAnchorItem = null
      focusItem = @selection.focusItem
      nextFocusItem = null
      outline = @outline
      outlineEditor = this
      expandedClones = []
      clonedItems = []
      oldToClonedIDs = {}

      for each in selectedItems
        clonedItems.push each.cloneItem (oldID, cloneID, cloneItem) ->
          oldItem = outline.getItemForID(oldID)
          if oldItem is anchorItem
            nextAnchorItem = cloneItem
          if oldItem is focusItem
            nextFocusItem = cloneItem
          if outlineEditor.isExpanded(oldItem)
            expandedClones.push(cloneItem)

      last = selectedItems[selectedItems.length - 1]
      insertBefore = last.nextSibling
      parent = insertBefore?.parent ? selectedItems[0].parent
      undoManager = @outline.undoManager

      undoManager.beginUndoGrouping()
      @setExpanded(expandedClones)
      parent.insertChildrenBefore(clonedItems, insertBefore)
      @moveSelectionRange(nextFocusItem, @selection.focusOffset, nextAnchorItem, @selection.anchorOffset)
      undoManager.endUndoGrouping()
      undoManager.setActionName('Duplicate Items')

  moveBranches: (items, newParent, newNextSibling) ->
    outline = @outlineBuffer.outline

    undoManager = outline.undoManager
    undoManager.beginUndoGrouping()

    selectedItemRange = @getSelectedItemRange()
    newParentNeedsExpand =
      newParent isnt @getHoistedItem() and
      not @isExpanded(newParent) and
      @isVisible(newParent)

    outline.beginChanges()
    outline.removeItemsFromParents items
    newParent.insertChildrenBefore items, newNextSibling
    outline.endChanges()

    if newParentNeedsExpand
      @setExpanded(newParent)
    @setSelectedItemRange(selectedItemRange)

    undoManager.endUndoGrouping()
    undoManager.setActionName('Move Items')
























  ###
  Section: Scripting
  ###

  evaluateScript: (script, options) ->
    result = '_wrappedValue': null
    try
      if options
        options = JSON.parse(options)._wrappedValue
      func = eval("(#{script})")
      r = func(this, options)
      if r is undefined
        r = null # survive JSON round trip
      result._wrappedValue = r
    catch e
      result._wrappedValue = "#{e.toString()}\n\tUse the Help > SDKRunner to debug"
    JSON.stringify(result)

  ###
  Section: Item Editor State
  ###

  getItemEditorState: (item) ->
    if item
      key = @id + '-editor-state'
      unless state = item.getUserData(key)
        state = new ItemEditorState
        item.setUserData key, state
      state

class ItemEditorState
  constructor: ->
    @marked = false
    @selected = false
    @expanded = true
    @matched = false
    @matchedAncestor = false

class NativeEditor
  constructor: ->
    @text = ''
    @selectedRange =
      location: 0
      length: 0

  Object.defineProperty @::, 'nativeSelectedRange',
    get: ->
      @selectedRange.location = Math.min(@selectedRange.location, @text.length)
      @selectedRange.length = Math.min(@selectedRange.length, @text.length - @selectedRange.location)
      @selectedRange

    set: (@selectedRange) ->

  Object.defineProperty @::, 'nativeTextContent',
    get: -> @text

  nativeTextBufferReplaceCharactersInRangeWithString: (range, text) ->
    @text = @text.substring(0, range.location) + text + @text.substring(range.location + range.length)

module.exports = OutlineEditor