OutlineBuffer = require './outline-buffer'
{CompositeDisposable} = require 'atom'
Outline = require '../../core/outline'
shortid = require '../../core/shortid'
OutlineLine = require './outline-line'

class OutlineEditor

  constructor: (outline, @nativeTextBuffer) ->
    @id = shortid()
    @isUpdatingNativeBuffer = 0
    @isUpdatingOutlineBuffer = 0
    @subscriptions = new CompositeDisposable
    @outlineBuffer = new OutlineBuffer(outline, this)

    @subscriptions.add @outlineBuffer.onDidChange (e) =>
      if not @isUpdatingOutlineBuffer
        range = e.oldCharacterRange
        nsrange = location: range.start, length: range.end - range.start
        @isUpdatingNativeBuffer++
        @nativeTextBuffer?.nativeTextBufferReplaceCharactersInRangeWithString(nsrange, e.newText)
        @isUpdatingNativeBuffer--

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

  getHoistedItem: ->
    @hoistedItem or @outline.root

  setHoistedItem: (item) ->
    @hoistedItem = item

    @outlineBuffer.isUpdatingBuffer++
    @outlineBuffer.removeLines(0, @outlineBuffer.getLineCount())
    @outlineBuffer.isUpdatingBuffer--

    newLines = []
    for each in @getHoistedItem().descendants
      newLines.push(new OutlineLine(this, each))
    @outlineBuffer.isUpdatingBuffer++
    @outlineBuffer.insertLines(0, newLines)
    @outlineBuffer.isUpdatingBuffer--

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

  _setExpandedState: (items, expanded) ->
    if not _.isArray(items)
      items = [items]

    for each in items
      if @isExpanded(each) isnt expanded
        @getItemEditorState(each).expanded = expanded

        @outlineBuffer.isUpdatingBuffer++
        if expanded
          # Insert lines for visible descendents of each
        else
          # Remove lines for descendents of each
        @outlineBuffer.isUpdatingBuffer--

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

    lastChild = item.getLastVisibleChild item, hoistedItem
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
    @expanded = false
    @matched = false
    @matchedAncestor = false

module.exports = OutlineEditor