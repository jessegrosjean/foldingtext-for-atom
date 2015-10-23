TaskPaper = require '../taskpaper'

OutlineEditorElement = require './outline-editor-element'
ItemSerializer = require './item-serializer'
{CompositeDisposable} = require 'atom'
ItemBuffer = require './item-buffer'
Mutation = require './mutation'
Outline = require './outline'
shortid = require './shortid'
_ = require 'underscore-plus'
assert = require 'assert'
Item = require './item'

class OutlineEditor

  constructor: (outline, @nativeEditor) ->
    @id = shortid()
    @isUpdatingNativeBuffer = 0
    @isUpdatingItemBuffer = 0
    @subscriptions = new CompositeDisposable
    @itemBuffer = new ItemBuffer(outline, this)
    outline = @itemBuffer.outline
    @nativeEditor ?= new NativeEditor()
    @searchQuery = ''
    @expandedBySearch = null

    TaskPaper.initOutline(outline)

    @subscriptions.add @itemBuffer.onDidBeginChanges =>
      @nativeEditor.beginEditing()

    @subscriptions.add @itemBuffer.onWillProcessOutlineMutation (mutation) =>
      target = mutation.target
      if @searchQuery
        if mutation.type is Mutation.CHILDREN_CHANGED and (target is @getHoistedItem() or @getHoistedItem().contains(target))
          for eachItem in mutation.addedItems
            @_addSearchResult(eachItem)
      if mutation.type is Mutation.CHILDREN_CHANGED
        if not target.hasChildren
          @setCollapsed(target)

    @subscriptions.add @itemBuffer.onDidProcessOutlineMutation (mutation) =>
      if mutation.type is Mutation.CHILDREN_CHANGED
        if range = @getVisibleBodyCharacterRange(mutation.target)
          @nativeEditor.invalidateDisplayForCharacterRange(range)

    @subscriptions.add @itemBuffer.onDidChange (e) =>
      if not @isUpdatingItemBuffer
        @isUpdatingNativeBuffer++
        nsrange = location: e.location, length: e.replacedLength
        @nativeEditor.replaceCharactersInRangeWithString(nsrange, e.insertedString)
        @isUpdatingNativeBuffer--

    undoManager = outline.undoManager

    @subscriptions.add undoManager.onDidOpenUndoGroup =>
      if not undoManager.isUndoing and not undoManager.isRedoing
        undoManager.setUndoGroupMetadata('undoSelection', @getSelectedItemRange())

    @subscriptions.add undoManager.onWillUndo (undoGroupMetadata) =>
      undoManager.setUndoGroupMetadata('redoSelection', @getSelectedItemRange())

    @subscriptions.add undoManager.onDidUndo (undoGroupMetadata) =>
      if s = undoGroupMetadata.undoSelection
        @setSelectedItemRange(s.startItem, s.startOffset, s.endItem, s.endOffset, true)

    @subscriptions.add undoManager.onDidOpenUndoGroup =>
      if not undoManager.isUndoing and not undoManager.isRedoing
        undoManager.setUndoGroupMetadata('undoSelection', @getSelectedItemRange())

    @subscriptions.add undoManager.onDidRedo (undoGroupMetadata) =>
      if s = undoGroupMetadata.redoSelection
        @setSelectedItemRange(s.startItem, s.startOffset, s.endItem, s.endOffset, true)

    @subscriptions.add @itemBuffer.onDidEndChanges =>
      @nativeEditor.endEditing()

    @setHoistedItem(outline.root)

  nativeTextBufferGuideRanges: (location, length) ->
    itemSpansInRange = @itemBuffer.getSpansInRange(location, length, true)
    ancestors = new Set()
    ancestors.add(@getHoistedItem())
    guideRanges = []
    for eachSpan in itemSpansInRange
      item = eachSpan.item
      ancestor = item.parent
      while not ancestors.has(ancestor)
        ancestorSpan = @itemBuffer.getItemSpanForItem(ancestor)
        lastVisibleSpan = @itemBuffer.getItemSpanForItem(@getLastVisibleDescendantOrSelf(ancestor))
        if ancestorSpan isnt lastVisibleSpan
          location = ancestorSpan.getLocation()
          end = lastVisibleSpan.getEnd()
          guideRanges.push
            string: ancestorSpan.item.bodyString
            location: location
            length: end - location
        ancestors.add(ancestor)
        ancestor = ancestor.parent
    guideRanges

  ###
  nativeTextBufferDrawingStateForRange: (location, length) ->
    itemSpansInRange = @itemBuffer.getSpansInRange(location, length, true)
    visitedAncestors = new Set(@getHoistedItem())
    visibleItemAncestorRanges = []
    visibleItemStates = []
    hoistedDepth = @getHoistedItem().depth

    for eachItemSpan in itemSpansInRange
      eachItem = eachItemSpan.item
      visibleItemStates.push
        depth: eachItem.depth - hoistedDepth
        gapBefore: not not (eachItem.previousSibling and not @isVisible(eachItem.previousSibling))
        hasChildren: eachItem.hasChildren
        collapsed: @isCollapsed(eachItem)

      ancestor = eachItem.parent
      while not visitedAncestors.has(ancestor)
        ancestorLine = @itemBuffer.getLineForItem(ancestor)
        firstChildLine = @itemBuffer.getLineForItem(@getFirstVisibleChild(ancestor))
        lastVisibleDescendantLine = @itemBuffer.getLineForItem(@getLastVisibleDescendantOrSelf(ancestor))
        visibleItemAncestorRanges.push
          ancestorStart: ancestorLine.getCharacterOffset() + ancestorLine.getTabCount()
          firstChildStart: firstChildLine.getCharacterOffset()
          lastVisibleDescendantEnd: lastVisibleDescendantLine.getCharacterOffset() + lastVisibleDescendantLine.getCharacterCount() - 1
        visitedAncestors.add(ancestor)
        ancestor = ancestor.parent

    if lastItemSpan = itemSpansInRange[itemSpansInRange.length - 1]
      lastItem = lastItemSpan.item
      if lastItem.nextSibling and not @isVisible(lastItem.nextSibling)
        visibleItemStates[visibleItemStates.length - 1].gapAfter = true

    {} =
      visibleItemAncestorRanges: visibleItemAncestorRanges
      visibleItemStates: visibleItemStates
  ###

  destroy: ->
    unless @destroyed
      @itemBuffer.destroy()
      @subscriptions.dispose()
      @destroyed = true

  ###
  Section: Hoisted Item
  ###

  hoist: ->
    if item = @getSelectedItems()[0]
      @setHoistedItem(item)

  unhoist: ->
    @setHoistedItem(@itemBuffer.outline.root)

  getHoistedItem: ->
    @itemBuffer.getHoistedItem()

  setHoistedItem: (item, force) ->
    if _.isString(item)
      item = @itemBuffer.outline.getItemForID(item)

    hoistedItem = @getHoistedItem()
    if item isnt hoistedItem or force
      savedSelection = @getSelectedItemRange()
      @nativeEditor.baseDepth = item.depth
      @itemBuffer.setHoistedItem(item)
      if not hoistedItem or hoistedItem.contains(item)
        @setSelectedRange(location: 0, length: 0)
      else
        @setSelectedItemRange(savedSelection)
      @nativeEditor.setHoistedItem(item)

  ###
  Section: Matched Items
  ###

  isMatched: (item) ->
    return item and @getItemEditorState(item).matched

  isMatchedAncestor: (item) ->
    return item and @getItemEditorState(item).matchedAncestor

  getQuery: ->
    @searchQuery

  setQuery: (query) ->
    @searchQuery = query

    # Remove old search state from the entire tree
    for each in @itemBuffer.outline.root.descendants
      itemState = @getItemEditorState(each)
      itemState.matched = false
      itemState.matchedAncestor = false
      if @expandedBySearch?.has(each)
        itemState.expanded = false

    # Clear the display text storage
    @itemBuffer.beginChanges()
    @itemBuffer.isUpdatingIndex++
    @itemBuffer.removeLines(0, @itemBuffer.getLineCount())
    @itemBuffer.isUpdatingIndex--
    @expandedBySearch = null

    # Update search state
    if query
      @expandedBySearch = new Set
      for eachItem in @getHoistedItem().evaluateItemPath(query)
        @_addSearchResult(eachItem)

    @nativeEditor.query = query
    @setHoistedItem(@getHoistedItem(), true)
    @itemBuffer.endChanges()

  _addSearchResult: (item) ->
    @getItemEditorState(item).matched = true
    ancestor = item.parent
    while ancestor
      ancestorState = @getItemEditorState(ancestor)
      if ancestorState.matchedAncestor
        ancestor = null
      else
        unless ancestorState.expanded
          ancestorState.expanded = true
          @expandedBySearch.add ancestor
        ancestorState.matchedAncestor = true
        ancestor = ancestor.parent

  ###
  Section: Expand & Collapse
  ###

  fold: (items, completely=false, allowFoldParent=true) ->
    items ?= @getSelectedItems()
    if not _.isArray(items)
      items = [items]

    selectionFoldable = false
    selectionFullyExpanded = true

    for each in items
      if each.hasChildren
        selectionFoldable = true
        unless @isExpanded(each)
          selectionFullyExpanded = false

    if selectionFoldable
      @_setExpandedState items, not selectionFullyExpanded, completely
    else if allowFoldParent
      parent = items[0].parent
      if @isVisible(parent)
        @setSelectedItemRange(parent, parent.bodyString.length)
        @fold(undefined, completely)

  foldCompletely: (items) ->
    @fold(items, true)

  increaseFoldingLevel: ->
    @setFoldingLevel(@getFoldingLevel() + 1)

  decreaseFoldingLevel: ->
    @setFoldingLevel(@getFoldingLevel() - 1)

  getFoldingLevel: ->
    minFoldedDepth = Number.MAX_VALUE
    maxItemDepth = 0

    @itemBuffer.iterateLines 0, @itemBuffer.getLineCount(), (line) =>
      item = line.item
      depth = item.depth
      if depth > maxItemDepth
        maxItemDepth = depth
      if item.hasChildren and @isCollapsed(item)
        if depth < minFoldedDepth
          minFoldedDepth = item.depth

    if minFoldedDepth is Number.MAX_VALUE
      maxItemDepth
    else
      minFoldedDepth

  setFoldingLevel: (level) ->
    items = @getHoistedItem().descendants
    @itemBuffer.beginChanges()
    @setCollapsed((item for item in items when item.depth >= level))
    @setExpanded((item for item in items when item.depth < level))
    @itemBuffer.endChanges()

  isExpanded: (item) ->
    return item and item.hasChildren and @getItemEditorState(item).expanded

  isCollapsed: (item) ->
    return item and item.hasChildren and not @getItemEditorState(item).expanded

  setExpanded: (items) ->
    @_setExpandedState items, true

  setCollapsed: (items) ->
    @_setExpandedState items, false

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

  _setExpandedState: (items, expanded, completely=false) ->
    items ?= @getSelectedItems()
    if not _.isArray(items)
      items = [items]

    if completely
      newItems = []
      for each in Item.getCommonAncestors(items)
        newItems.push each
        Array.prototype.push.apply(newItems, each.descendants)
      items = newItems

    selectedItemRange = @getSelectedItemRange()
    @itemBuffer.beginChanges()
    #@nativeEditor.invalidateDisplayForCharacterRange()
    @itemBuffer.isUpdatingIndex++
    if expanded
      # for better animations
      for each in items
        if not @isVisible(each)
          @getItemEditorState(each).expanded = expanded
      for each in items
        if @isExpanded(each) isnt expanded
          @expandedBySearch?.delete(each)
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
    @itemBuffer.endChanges()
    @itemBuffer.isUpdatingIndex--
    @setSelectedItemRange(selectedItemRange)

  _insertVisibleDescendantLines: (item) ->
    if itemSpan = @itemBuffer.getItemSpanForItem(item)
      if each = @getFirstVisibleChild(item)
        insertLines = []
        end = @getNextVisibleItem(@getLastVisibleDescendantOrSelf(item))
        while each isnt end
          insertLines.push(@itemBuffer.createSpanForItem(each))
          each = @getNextVisibleItem(each)
        @itemBuffer.insertLines(itemSpan.getSpanBuffer() + 1, insertLines)

  _removeDescendantLines: (item) ->
    if itemSpan = @itemBuffer.getItemSpanForItem(item)
      start = itemSpan.getSpanBuffer() + 1
      end = start
      while item.contains(@itemBuffer.getLine(end)?.item)
        end++
      @itemBuffer.removeLines(start, end - start)

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

    if @searchQuery
      itemState = @getItemEditorState(item)
      itemState.matched or itemState.matchedAncestor
    else
      return true

  # Public: Make the given item visible in the outline, expanding ancestors,
  # removing filter, and unhoisting as needed.
  #
  # - `item` {Item} to make visible.
  makeVisible: (item) ->
    if item and not @isVisible(item) and item.isInOutline and item.outline is @itemBuffer.outline
      @itemBuffer.beginChanges()
      hoistedItem = @getHoistedItem()
      while not hoistedItem.contains(item)
        @unhoist()
        hoistedItem = @getHoistedItem()

      parentsToExpand = []
      eachParent = item.parent
      while eachParent and eachParent isnt hoistedItem
        if @isCollapsed eachParent
          parentsToExpand.push eachParent
        eachParent = eachParent.parent

      @setExpanded(parentsToExpand)
      @itemBuffer.endChanges()

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

  getLastVisibleDescendantLocation: (item, hoistedItem) ->
    if last = @getLastVisibleDescendantOrSelf(item, hoistedItem)
      unless last is item
        if range = @getVisibleBodyCharacterRange(item)
          return range.location + range.length
    0

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

  getVisibleBodyCharacterRange: (item) ->
    itemSpan = @itemBuffer.getItemSpanForItem(item)
    if itemSpan
      location: itemSpan.getLocation(), length: itemSpan.getLength()
    else
      null

  getVisibleBranchCharacterRange: (item, hoistedItem) ->
    startItemSpan = @itemBuffer.getItemSpanForItem(item)
    endItemSpan = @itemBuffer.getItemSpanForItem(@getLastVisibleDescendantOrSelf(item, hoistedItem))
    start = startItemSpan.getLocation()
    end = endItemSpan.getLocation() + endItemSpan.getLength()
    {} =
      location: start
      length: end - start

  ###
  Section: Selection
  ###

  # Public: Returns the selection {Range}.
  getSelectedRange: ->
    @getSelectedRanges()[0]

  getSelectedRanges: ->
    selectedRange = @nativeEditor.selectedRange
    length = @itemBuffer.getLength()
    if selectedRange.location > length
      selectedRange.location = length
      selectedRange.length = 0
    if selectedRange.location + selectedRange.length > length
      selectedRange.length = length - selectedRange.location
    [selectedRange]

  getSelectedItems: ->
    selectedItems = []
    for each in @getSelectedRanges()
      rangeItems = (each.item for each in @itemBuffer.getSpansInRange(each.location, each.length, true))
      last = selectedItems[selectedItems.length - 1]
      while rangeItems.length > 0 and rangeItems[0] is last
        rangeItems.shift()
      Array.prototype.push.apply(selectedItems, rangeItems)
    selectedItems

  getSelectedItemRange: ->
    range = @getSelectedRange()
    @itemBuffer.getItemRange(range.location, range.length)

  selectItem: ->
    @setSelectedItemRange(@getSelectedItemRange().rangeByExtendingToItem())

  selectBranch: ->
    @setSelectedItemRange(@getSelectedItemRange().rangeByExtendingToBranch())

  # Public: Sets the selection.
  #
  # - `range` {Range}
  setSelectedRange: (range) ->
    @setSelectedRanges([range])

  setSelectedRanges: (ranges) ->
    @nativeEditor.selectedRange = ranges[0]

  setSelectedItemRange: (startItem, startOffset, endItem, endOffset, reveal=false) ->
    if startItem
      range = @itemBuffer.getRangeFromItemRange(startItem, startOffset, endItem, endOffset, reveal)
      @setSelectedRange(range)

  ###
  Section: Insert
  ###

  insertNewline: ->
    outline = @itemBuffer.outline
    undoManager = outline.undoManager
    undoManager.beginUndoGrouping()

    selectedRange = @getSelectedRange()
    selectedItemRange = @getSelectedItemRange()

    if selectedRange.length
      @itemBuffer.replaceRange(selectedRange.location, selectedRange.length, '')
      selectedRange.length = 0

    startItem = selectedItemRange.startItem
    startItemSpan = @itemBuffer.getItemSpanForItem(startItem)
    startOffset = selectedItemRange.startOffset

    match = startItem.bodyString.match(/(- )(.*)/)
    prefix = match?[1] ? ''
    content = match?[2] ? startItem.bodyString
    lead = prefix.length

    if startOffset <= lead and (not prefix or content)
      @insertItem('', true)
      @setSelectedItemRange(startItem, startOffset)
    else if startOffset is lead and (prefix and not content)
      startItem.bodyString = ''
    else
      splitText = startItem.bodySubattributedString(startOffset, -1)
      startItem.replaceBodyRange(startOffset, -1, '')

      if prefix and splitText.string.indexOf(prefix) isnt 0
        splitText.insertText(0, prefix)
        @insertItem(splitText)
        selectedRange = @getSelectedRange()
        selectedRange.location += prefix.length
        @setSelectedRange(selectedRange)
      else
        @insertItem(splitText)

    undoManager.endUndoGrouping()

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

    selectedItems = @getSelectedItems()
    insertBefore
    parent

    if above
      selectedItem = selectedItems[0]
      if not selectedItem
        parent = @getHoistedItem()
        insertBefore = parent.firstChild
      else
        parent = selectedItem.parent
        insertBefore = selectedItem
    else
      selectedItem = selectedItems[selectedItems.length - 1]
      if not selectedItem
        parent = @getHoistedItem()
        insertBefore = null
      else if @isExpanded(selectedItem)
        parent = selectedItem
        insertBefore = parent.firstChild
      else
        parent = selectedItem.parent
        insertBefore = selectedItem.nextSibling

    outline = parent.outline
    insertItem = outline.createItem(text)
    undoManager = outline.undoManager

    undoManager.beginUndoGrouping()
    parent.insertChildBefore(insertItem, insertBefore)
    undoManager.endUndoGrouping()
    @setSelectedItemRange(insertItem)

    undoManager.setActionName('Insert Item')

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
    if not _.isArray(items)
      items = [items]

    if items.length
      selectedItemRange = @getSelectedItemRange()
      minDepth = @getHoistedItem().depth + 1
      outline = @itemBuffer.outline
      undoManager = outline.undoManager
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
          referenceItem = @getNextVisibleItem(nextVisibleItem)
        when 'left'
          depthDelta = -1
          referenceItem = endItem.nextItem
        when 'right'
          depthDelta = 1
          referenceItem = endItem.nextItem

      undoManager.beginUndoGrouping()
      outline.beginChanges()

      expandItems = []
      disposable = outline.onDidChange (mutation) ->
        if mutation.type is Mutation.CHILDREN_CHANGED
          if not (mutation.target in expandItems)
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
      undoManager.endUndoGrouping()

  ###
  Section: Move Branches
  ###

  moveBranchesUp: (items) ->
    @_moveBranchesInDirection(items, 'up')

  moveBranchesDown: (items) ->
    @_moveBranchesInDirection(items, 'down')

  moveBranchesLeft: (items) ->
    @_moveBranchesInDirection(items, 'left')

  moveBranchesRight: (items) ->
    @_moveBranchesInDirection(items, 'right')

  _moveBranchesInDirection: (items, direction) ->
    items ?= @getSelectedItems()
    if not _.isArray(items)
      items = [items]
    items = Item.getCommonAncestors(items)

    if items.length > 0
      startItem = items[0]
      newNextSibling
      newParent

      if direction is 'up'
        newNextSibling = @getPreviousVisibleSibling(startItem)
        if newNextSibling
          newParent = newNextSibling.parent
      else if direction is 'down'
        endItem = items[items.length - 1]
        newPreviousSibling = @getNextVisibleSibling(endItem)
        if newPreviousSibling
          newParent = newPreviousSibling.parent
          newNextSibling = @getNextVisibleSibling(newPreviousSibling)
      else if direction is 'left'
        startItemParent = startItem.parent
        if startItemParent isnt @getHoistedItem()
          newParent = startItemParent.parent
          newNextSibling = @getNextVisibleSibling(startItemParent)
          while newNextSibling and newNextSibling in items
            newNextSibling = @getNextVisibleSibling(newNextSibling)
      else if direction is 'right'
        newParent = @getPreviousVisibleSibling(startItem)

      if newParent
        @moveBranches(items, newParent, newNextSibling)

  deleteItems: (items) ->
    items ?= @getSelectedItems()
    if not _.isArray(items)
      items = [items]

    selectedItemRange = startItem: @getPreviousVisibleItem(items[0]), startOffset: -1
    outline = @itemBuffer.outline
    undoManager = outline.undoManager
    undoManager.beginUndoGrouping()
    outline.beginChanges()
    outline.removeItems(items)
    outline.endChanges()
    @setSelectedItemRange(selectedItemRange)
    undoManager.endUndoGrouping()

  groupBranches: (items) ->
    items ?= @getSelectedItems()
    if not _.isArray(items)
      items = [items]
    items = Item.getCommonAncestors(items)

    if items.length > 0
      outline = @itemBuffer.outline
      first = items[0]
      group = outline.createItem ''

      undoManager = outline.undoManager
      undoManager.beginUndoGrouping()

      first.parent.insertChildBefore(group, first)
      @setSelectedItemRange(group)
      @moveBranches(items, group)

      undoManager.endUndoGrouping()
      undoManager.setActionName('Group Items')

  duplicateBranches: (items) ->
    items ?= @getSelectedItems()
    if not _.isArray(items)
      items = [items]
    items = Item.getCommonAncestors(items)

    if items.length > 0
      itemRange = @getSelectedItemRange()
      outline = @itemBuffer.outline
      expandedClones = []
      clonedItems = []

      for each in items
        clonedItems.push each.cloneItem true, (oldID, cloneID, cloneItem) =>
          oldItem = outline.getItemForID(oldID)
          if oldItem is itemRange.startItem
            itemRange.startItem = cloneItem
          if oldItem is itemRange.endItem
            itemRange.endItem = cloneItem
          if @isExpanded(oldItem)
            expandedClones.push(cloneItem)

      last = items[items.length - 1]
      insertBefore = last.nextSibling
      parent = insertBefore?.parent ? items[0].parent
      undoManager = outline.undoManager

      undoManager.beginUndoGrouping()
      @setExpanded(expandedClones)
      parent.insertChildrenBefore(clonedItems, insertBefore)
      @setSelectedItemRange(itemRange)
      undoManager.endUndoGrouping()
      undoManager.setActionName('Duplicate Items')

  promoteChildBranches: (item) ->
    item ?= @getSelectedItems()[0]
    if item
      @moveBranches(item.children, item.parent, item.nextSibling)
      @itemBuffer.outline.undoManager.setActionName('Promote Children')

  demoteTrailingSiblingBranches: (item) ->
    item ?= @getSelectedItems()[0]
    if item
      trailingSiblings = []

      each = item.nextSibling
      while each
        trailingSiblings.push(each)
        each = each.nextSibling

      if trailingSiblings.length > 0
        @moveBranches(trailingSiblings, item, null)
        @itemBuffer.outline.undoManager.setActionName('Demote Siblings')

  moveBranches: (items, newParent, newNextSibling) ->
    items ?= @getSelectedItems()
    if not _.isArray(items)
      items = [items]
    items = Item.getCommonAncestors(items)

    if items[0] is newNextSibling
      return

    outline = @itemBuffer.outline

    undoManager = outline.undoManager
    undoManager.beginUndoGrouping()

    selectedItemRange = @getSelectedItemRange()
    newParentNeedsExpand =
      newParent isnt @getHoistedItem() and
      not @isExpanded(newParent) and
      @isVisible(newParent)

    outline.beginChanges()
    Item.removeItemsFromParents(items)
    newParent.insertChildrenBefore items, newNextSibling
    outline.endChanges()

    if newParentNeedsExpand
      @setExpanded(newParent)
    @setSelectedItemRange(selectedItemRange)

    undoManager.endUndoGrouping()
    undoManager.setActionName('Move Items')

  ###
  Section: Attributes
  ###

  setAttribute: (items, name, value) ->
    items ?= @getSelectedItems()
    outline = @itemBuffer.outline
    undoManager = outline.undoManager
    selectedItemRange = @getSelectedItemRange()

    undoManager.beginUndoGrouping()
    outline.beginChanges()
    for each in items
      each.setAttribute(name, value)
    outline.endChanges()
    undoManager.endUndoGrouping()
    undoManager.setActionName('Set Attribute')

    @setSelectedItemRange(selectedItemRange)

  toggleAttribute: (name, value='', items=@getSelectedItems()) ->
    if items
      for each in items
        if each.hasAttribute(name)
          value = null
    @setAttribute(items, name, value)

  ###
  Section: Serialization
  ###

  serializeItems: (items, mimeType) ->
    if items
      items = Item.flattenItemHiearchy(items, false)
    items ?= @itemBuffer.outline.root.descendants
    ItemSerializer.serializeItems(items, self, mimeType)

  serializeRange: (location, length, mimeType) ->
    { startItem, startOffset, endItem, endOffset } = @itemBuffer.getItemRange(location, length)
    items = []

    each = startItem
    while each
      items.push(each)
      if each is endItem
        each = null
      else
        each = @getNextVisibleItem(each)

    ItemSerializer.serializeItems items, @, mimeType,
      startOffset: startOffset
      endOffset: endOffset

  deserializeItems: (data, mimeType) ->
    ItemSerializer.deserializeItems(data, @itemBuffer.outline, mimeType)

  replaceRangeWithString: (location, length, string) ->
    if not @isUpdatingNativeBuffer
      outline = @itemBuffer.outline
      undoManager = outline.undoManager

      undoManager.beginUndoGrouping()
      @isUpdatingItemBuffer++
      outline.beginChanges()
      @itemBuffer.replaceRange(location, length, string)
      outline.endChanges()
      @isUpdatingItemBuffer--
      undoManager.endUndoGrouping()

  replaceRangeWithItems: (location, length, items) ->
    outline = @itemBuffer.outline
    undoManager = outline.undoManager
    undoManager.beginUndoGrouping()

    outline.beginChanges()
    @itemBuffer.deleteRange(location, length)
    items = Item.flattenItemHiearchy(items)
    firstItem = items[0]
    insertAt = @itemBuffer.getSpanInfoAtLocation(location, true)
    insertAtItem = insertAt.span.item
    nextSelection = {}

    if items.length > 1
      trailingBody = insertAtItem.bodySubattributedString(insertAt.location, -1)
      insertAtItem.replaceBodyRange(insertAt.location, -1, firstItem.bodyAttributedString)
      items = items.slice(1)
      lastItem = items[items.length - 1]

      for each in items
        each.indent += (insertAtItem.depth - 1)

      outline.insertItemsBefore(items, insertAtItem.nextItem)
      lastItem.appendBody(trailingBody)
      nextSelection.item = lastItem
      nextSelection.location = lastItem.bodyString.length - trailingBody.length
    else
      insertAtItem.replaceBodyRange(insertAt.location, 0, firstItem.bodyAttributedString)
      nextSelection.item = insertAtItem
      nextSelection.location = insertAt.location + firstItem.bodyString.length

    @setSelectedItemRange(nextSelection.item, nextSelection.location)

    outline.endChanges()

    undoManager.endUndoGrouping()
    undoManager.setActionName('Paste')

  loadItems: (items) ->
    outline = @itemBuffer.outline
    undoManager = outline.undoManager
    undoManager.disableUndoRegistration()
    outline.beginChanges()
    outline.root.removeChildren(outline.root.children)
    outline.root.appendChildren(items)
    outline.endChanges()
    undoManager.enableUndoRegistration()

  ###
  Section: Commands
  ###

  performCommand: (commandName, detail) ->
    atom.commands.dispatch(atom.views.getView(@), commandName, detail)

  validateCommandMenuItem: (commandName, menuItem) ->
    atom.views.getView(@).validateCommandMenuItem?(commandName, menuItem)

  ###
  Section: Delegate
  ###

  clickedOnLink: (item, link) ->
    if link is 'toggledone'
      @toggleAttribute('data-done', '', [item])
    else
      @setQuery(link)
    true

  ###
  Section: Item Editor State
  ###

  getItemEditorState: (item) ->
    if item
      unless state = item.getUserData(@id)
        state = new ItemEditorState
        item.setUserData @id, state
      state

class ItemEditorState
  constructor: ->
    @marked = false
    @selected = false
    @expanded = true
    @matched = false
    @matchedAncestor = false

class NativeEditor
  constructor: (@text='') ->
    @query = ''
    @selectedRange =
      location: 0
      length: 0

  Object.defineProperty @::, 'query',
    get: ->
      @_query
    set: (@_query) ->

  Object.defineProperty @::, 'baseDepth',
    get: ->
      @_baseDepth
    set: (@_baseDepth) ->

  Object.defineProperty @::, 'selectedRange',
    get: ->
      @_selectedRange.location = Math.min(@_selectedRange.location, @text.length)
      @_selectedRange.length = Math.min(@_selectedRange.length, @text.length - @_selectedRange.location)
      @_selectedRange
    set: (@_selectedRange) ->

  scrollRangeToVisible: (range) ->

  beginEditing: ->

  setHoistedItem: (item) ->

  invalidateAttributesForCharacterRange: (range) ->

  invalidateDisplayForCharacterRange: (range) ->

  replaceCharactersInRangeWithString: (range, text) ->
    @text = @text.substring(0, range.location) + text + @text.substring(range.location + range.length)

  endEditing: ->

atom.views.addViewProvider OutlineEditor, (editor) ->
  new OutlineEditorElement().initialize(editor)

module.exports = OutlineEditor