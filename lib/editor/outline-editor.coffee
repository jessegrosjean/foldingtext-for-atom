# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

OutlineEditorItemState = require './outline-editor-item-state'
OutlineEditorElement = require './outline-editor-element'
AttributedString = require '../core/attributed-string'
ItemBodyEncoder = require '../core/item-body-encoder'
ItemSerializer = require '../core/item-serializer'
{Emitter, CompositeDisposable} = require 'atom'
UndoManager = require '../core/undo-manager'
rafdebounce = require './raf-debounce'
ItemPath = require '../core/item-path'
Velocity = require 'velocity-animate'
Mutation = require '../core/mutation'
shortid = require '../core/shortid'
Outline = require '../core/outline'
Selection = require './selection'
_ = require 'underscore-plus'
Item = require '../core/item'
assert = require 'assert'
path = require 'path'

# Public: Editor for {Outline}s.
#
# Maintains all editing state for the outline incuding: hoisted items,
# filtering items, expanded items, and item selection.
#
# A single {Outline} can belong to multiple editors. For example, if the same
# outline is open in two different panes, Atom creates a separate editor for
# each pane. If the outline is manipulated the changes are reflected in both
# editors, but each maintains its own selection, expanded items, etc.
#
# The easiest way to get hold of `OutlineEditor` objects is by registering a
# callback with `::observeOutlineEditors` through the {FoldingTextService}.
module.exports =
class OutlineEditor

  atom.views.addViewProvider OutlineEditor, (editor) ->
    editor.outlineEditorElement

  constructor: (outline, params) ->
    id = shortid()
    @emitter = new Emitter()
    @subscriptions = new CompositeDisposable
    @isOutlineEditor = true
    @outline = null
    @_overrideIsFocused = false
    @_selection = new Selection(this)
    @_textModeExtendingFromSnapbackRange = null
    @_textModeTypingFormattingTags = {}
    @_selectionVerticalAnchor = undefined
    @_disableSyncDOMSelectionToEditor = false
    @_search = {}
    @_searchCollapsed = {}
    @_searchAttributeShortcuts = {}
    @_searchResults = []

    @_hoistStack = []
    @_dragState =
      draggedItem: null
      dropEffect: null
      dropParentItem: null
      dropInsertBeforeItem: null
      dropInsertAfterItem: null

    @outline = outline or Outline.buildOutlineSync()
    @subscribeToOutline()

    outlineEditorElement = document.createElement('ft-outline-editor').initialize(this)
    outlineEditorElement.id = id
    outlineEditorElement.classList.add('beditor')
    @outlineEditorElement = outlineEditorElement
    if params?.hostElement
      params.hostElement.appendChild(outlineEditorElement)

    @serializedState =
      hoistedItemIDs: params?.hoistedItemIDs
      expandedItemIDs: params?.expandedItemIDs

    @loadSerializedState()

  copy: ->
    new OutlineEditor(@outline)

  serialize: ->
    {} =
      deserializer: 'OutlineEditor'
      hoistedItemIDs: (each.id for each in @_hoistStack)
      expandedItemIDs: (each.id for each in @outline.getItems() when @isExpanded each)
      filePath: @getPath()

  loadSerializedState: ->
    hoistedItemIDs = @serializedState.hoistedItemIDs
    expandedItemIDs = @serializedState.expandedItemIDs
    unless expandedItemIDs
      expandedItemIDs = @outline.serializedState.expandedItemIDs or []
    @setExpanded (@outline.getItemsForIDs expandedItemIDs)
    hoistedItems = @outline.getItemsForIDs hoistedItemIDs
    if hoistedItems.length
      @setHoistedItemsStack hoistedItems
    else
      @hoistItem @outline.root

  subscribeToOutline: ->
    outline = @outline
    undoManager = outline.undoManager

    outline.retain()

    @subscriptions.add outline.onDidChange @outlineDidChange.bind(this)

    @subscriptions.add outline.onDidChangePath =>
      unless atom.project.getPaths()[0]?
        atom.project.setPaths([path.dirname(@getPath())])
      @emitter.emit 'did-change-title', @getTitle()

    @subscriptions.add outline.onWillReload =>
      @outlineEditorElement.disableAnimation()

    @subscriptions.add outline.onDidReload =>
      @loadSerializedState()
      @outlineEditorElement.enableAnimation()

    @subscriptions.add outline.onDidDestroy => @destroy()

    @subscriptions.add undoManager.onDidOpenUndoGroup =>
      if not undoManager.isUndoing and not undoManager.isRedoing
        undoManager.setUndoGroupMetadata('undoSelection', @selection)

    @subscriptions.add undoManager.onWillUndo (undoGroupMetadata) =>
      @_overrideIsFocused = @isFocused()
      undoManager.setUndoGroupMetadata('redoSelection', @selection)

    @subscriptions.add undoManager.onDidUndo (undoGroupMetadata) =>
      selectionRange = undoGroupMetadata.undoSelection
      if selectionRange
        @moveSelectionRange(selectionRange)
      @_overrideIsFocused = false

    @subscriptions.add undoManager.onWillRedo (undoGroupMetadata) =>
      @_overrideIsFocused = @isFocused()

    @subscriptions.add undoManager.onDidRedo (undoGroupMetadata) =>
      selectionRange = undoGroupMetadata.redoSelection
      if selectionRange
        @moveSelectionRange(selectionRange)
      @_overrideIsFocused = false

  outlineDidChange: (mutations) ->
    if @getSearch()?.query
      hoistedItem = @getHoistedItem()
      for eachMutation in mutations
        if eachMutation.type is Mutation.CHILDREN_CHANGED
          for eachItem in eachMutation.addedItems
            if hoistedItem.contains(eachItem)
              @_addSearchResult(eachItem)

    selectionRange = @selection
    @_overrideIsFocused = @isFocused()
    @outlineEditorElement.outlineDidChange(mutations)
    @moveSelectionRange(selectionRange)
    @_overrideIsFocused = false

    for eachMutation in mutations
      if eachMutation.type is Mutation.CHILDREN_CHANGED
        targetItem = eachMutation.target
        if not targetItem.hasChildren
          @setCollapsed targetItem

    @_updateBackgroundMessage()

  destroy: ->
    unless @destroyed
      @destroyed = true
      @subscriptions.dispose()
      @outline.release @id
      @outlineEditorElement.destroy()
      @emitter.emit 'did-destroy'

  ###
  Section: Attributes
  ###

  # Public: Read-only unique (not persistent) {String} editor ID.
  id: null
  Object.defineProperty @::, 'id',
    get: -> @outlineEditorElement.id

  # Public: The {Outline} that is being edited.
  outline: null

  ###
  Section: Event Subscription
  ###

  # Essential: Calls your `callback` when the editor's outline title has
  # changed.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeTitle: (callback) ->
    @emitter.on 'did-change-title', callback

  # Essential: Calls your `callback` when the editor's outline path, and
  # therefore title, has changed.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangePath: (callback) ->
    @outline.onDidChangePath(callback)

  # Public: Invoke the given callback when the editor's outline changes.
  #
  # See {Outline} Examples for an example of subscribing to these events.
  #
  # - `callback` {Function} to be called when the outline changes.
  #   - `mutations` {Array} of {Mutation}s describing the changes.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChange: (callback) ->
    @outline.onDidChange(callback)

  # Public: Calls your `callback` when the result of {::isModified} changes.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeModified: (callback) ->
    @outline.onDidChangeModified(callback)

  # Public: Calls your `callback` when the editor's outline's underlying
  # file changes on disk at a moment when the result of {::isModified} is
  # true.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidConflict: (callback) ->
    @outline.onDidConflict(callback)

  # Public: Invoke the given callback after the editor's outline is saved to
  # disk.
  #
  # * `callback` {Function} to be called after the buffer is saved.
  #   * `event` {Object} with the following keys:
  #     * `path` The path to which the buffer was saved.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidSave: (callback) ->
    @outline.onDidSave(callback)

  # Public: Invoke the given callback when the editor is destroyed.
  #
  # * `callback` {Function} to be called when the editor is destroyed.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  # Public: Calls your `callback` when {Selection} changes in the editor.
  #
  # * `callback` {Function}
  #   * `selection` {Selection} in editor.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeSelection: (callback) ->
    @emitter.on 'did-change-selection', callback

  # Public: Calls your `callback` when {Selection} changes in the editor.
  # Immediately calls your callback for existing selection.
  #
  # * `callback` {Function}
  #   * `selection` {Selection} in editor.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeSelection: (callback) ->
    callback @selection
    @onDidChangeSelection(callback)

  # Public: Calls your `callback` when the hoisted {Item} changes in the
  # editor.
  #
  # * `callback` {Function}
  #   * `item` Hoisted {Item} in editor.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeHoistedItem: (callback) ->
    @emitter.on 'did-change-hoisted-item', callback

  # Public: Calls your `callback` when the editor's search changes.
  #
  # * `callback` {Function}
  #   * `searchInfo`
  #     - `query` Editor's {String} search query.
  #     - `type` Editor's {String} search type.
  #     - `keywords`
  #     - `error`
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeSearch: (callback) ->
    @emitter.on 'did-change-search', callback

  ###
  Section: Hoisting Items
  ###

  # Public: Returns the current hoisted {Item}.
  getHoistedItem: ->
    @_hoistStack[@_hoistStack.length - 1]

  # Public: Push a new hoisted {Item}.
  #
  # - `item` {Item} to hoist.
  hoistItem: (item) ->
    item ?= @selection.focusItem
    hoistedItem = @getHoistedItem()

    if item and item isnt hoistedItem
      if hoistedItem
        hoistedItem.setUserData(@id + '-unhoist-viewport-top', @outlineEditorElement.getViewportRect().top)
      stack = @_hoistStack.slice()
      stack.push item
      hadValidSelection = @selection.isValid
      @setHoistedItemsStack stack
      child = @getFirstVisibleChild item
      if child and (not hadValidSelection or child.isEmpty)
        @moveSelectionRange child, 0

  # Public: Pop the current hoisted {Item}.
  unhoist: ->
    unless @getHoistedItem().isRoot
      stack = @_hoistStack.slice()
      lastHoisted = stack.pop()
      @setHoistedItemsStack(stack)
      unless @selection.isValid
        @moveSelectionRange(lastHoisted)

  setHoistedItemsStack: (newHoistedItems) ->
    oldHoistedItem = @getHoistedItem()
    outline = @outline
    next

    # Validate that hoisted items each contain the next.
    for each in newHoistedItems by -1
      unless each.isInOutline and each.outline is outline
        newHoistedItems.pop()
      else
        if next
          if not each.contains(next)
            newHoistedItems.splice(i, 1)
          else
            next = each
        else
          next = each

    # Validate that root is first hoisted item.
    unless newHoistedItems[0] is outline.root
      newHoistedItems = [outline.root]

    newHoistedItem = newHoistedItems[newHoistedItems.length - 1]

    if oldHoistedItem isnt newHoistedItem
      # Add placeholder child if non exists
      unless newHoistedItem.firstChild
        newHoistedItem.appendChild outline.createItem()

      # Temporarily expand new hoisted item if it's not already expanded so
      # that it will have visible child that hoist animations can get geometry
      # from and use as basepoint to start animation.
      didExpandHoistedItem = false
      unless @isExpanded newHoistedItem
        @outlineEditorElement.disableAnimation()
        @setExpanded newHoistedItem
        didExpandHoistedItem = true
        @outlineEditorElement.enableAnimation()

      if oldHoistedItem
        # Remove placeholder child if it's empty
        if oldHoistedItem.children.length is 1 and oldHoistedItem.firstChild.isEmpty
          oldHoistedItem.firstChild.removeFromParent()

      @outlineEditorElement.prepareUpdateHoistedItem(oldHoistedItem, newHoistedItem)
      @_hoistStack = newHoistedItems
      @outlineEditorElement.updateHoistedItem(oldHoistedItem, newHoistedItem)

      if didExpandHoistedItem
        @outlineEditorElement.disableAnimation()
        @setCollapsed newHoistedItem
        @outlineEditorElement.enableAnimation()

      @emitter.emit 'did-change-hoisted-item', newHoistedItem

    @outlineEditorElement.disableScrolling()
    @_revalidateSelectionRange()
    @outlineEditorElement.enableScrolling()
    @_updateBackgroundMessage()

  _updateBackgroundMessage: ->
    if @getFirstVisibleItem()
      @outlineEditorElement.setBackgroundMessage ''
    else
      if @getSearch().query and @getHoistedItem().firstChild
        @outlineEditorElement.setBackgroundMessage 'Clear the search to see items.'
      else
        @outlineEditorElement.setBackgroundMessage 'Press <span class="keystroke">Return</span> to create new item.'

  ###
  Section: Expanding Items
  ###

  # Public: Returns true if the item is expanded.
  #
  # - `item` {Item} to test.
  isExpanded: (item) ->
    return item and @editorItemState(item).expanded

  # Public: Returns true if the item is collapsed.
  #
  # - `item` {Item} to test.
  isCollapsed: (item) ->
    return item and not @editorItemState(item).expanded

  # Public: Expand the given items in this editor.
  #
  # - `items` {Item} or {Array} of items.
  setExpanded: (items) ->
    @_setExpandedState items, true

  # Public: Collapse the given items in this editor.
  #
  # - `items` {Item} or {Array} of items.
  setCollapsed: (items) ->
    @_setExpandedState items, false

  _setExpandedState: (items, expanded) ->
    items ?= @selection.itemsCommonAncestors

    if not _.isArray(items)
      items = [items]

    if expanded
      # for better animations
      for each in items
        if not @isVisible(each)
          @editorItemState(each).expanded = expanded

      for each in items
        if @isExpanded(each) isnt expanded
          @editorItemState(each).expanded = expanded
          @outlineEditorElement.updateItemExpanded(each)
    else
      # for better animations
      for each in Item.getCommonAncestors(items)
        if @isExpanded(each) isnt expanded
          @editorItemState(each).expanded = expanded
          @outlineEditorElement.updateItemExpanded(each)

      for each in items
        @editorItemState(each).expanded = expanded

    @outlineEditorElement.disableScrolling()
    @_revalidateSelectionRange()
    @outlineEditorElement.enableScrolling()

  foldItems: (items, fully) ->
    @_foldItems items, false, fully

  unfoldItems: (items, fully) ->
    @_foldItems items, true, fully

  toggleFoldItems: (items, fully) ->
    @_foldItems items, undefined, fully

  _foldItems: (items, expand, fully) ->
    items ?= @selection.itemsCommonAncestors
    unless _.isArray(items)
      items = [items]

    unless items.length
      return

    unless expand
      first = items[0]
      unless first.hasChildren
        parent = first.parent
        if @isVisible(parent)
          @moveSelectionRange(parent)
          @_foldItems(parent, expand, fully)
          return

    foldItems = []

    if expand is undefined
      expand = not @isExpanded((each for each in items when each.hasChildren)[0])

    if fully
      for each in Item.getCommonAncestors(items) when each.hasChildren and @isExpanded(each) isnt expand
        foldItems.push each
        foldItems.push each for each in each.descendants when each.hasChildren and @isExpanded(each) isnt expand
    else
      foldItems = (each for each in items when each.hasChildren and @isExpanded(each) isnt expand)

    if foldItems.length
      @_setExpandedState foldItems, expand

  toggleFullyFoldItems: (items) ->
    @toggleFoldItems items, true

  ###
  Section: Searching Items
  ###

  # Public: Search type used for item path search syntax.
  @ITEM_PATH_SEARCH: 'itempath'

  # Public: Search type used for xpath search syntax.
  @X_PATH_SEARCH: 'xpath'

  # Public: Add a shortcut for an attribute name in the
  # {OutlineEditor.ITEM_PATH_SEARCH} search syntax. For example if you want
  # the user to be able to type `@status` instead of having to type `@data-
  # status` then you can add `status` as a shortcut for `data-status`.
  #
  # - `shortcutName` {String} Shortcut name, `status` for example.
  # - `attributeName` {String} Attribute name, 'data-status' for example.
  #
  addSearchAttributeShortcut: (shortcutName, attributeName) ->
    @_searchAttributeShortcuts[shortcutName] = attributeName
    if @search
      setSearch @search

  # Public: Returns search {Object} with keys:
  #
  # - `query` Search {String}
  # - `type` either {OutlineEditor.ITEM_PATH_SEARCH} or {OutlineEditor.X_PATH_SEARCH}
  # - `keywords` {Array} of recognized keyword ranges.
  # - `error` Any error encountered while parsing search query.
  getSearch: ->
    @_search

  # Public: Sets search used to filter the contents of this outline. The
  # search `type` parameter determines how the search is performed. It
  # defaults to {OutlineEditor.ITEM_PATH_SEARCH} syntax, but you can also use
  # {OutlineEditor.X_PATH_SEARCH} syntax.
  #
  # - `query` {String} Search query.
  # - `type` (optional) {OutlineEditor.ITEM_PATH_SEARCH} (default) or {OutlineEditor.X_PATH_SEARCH}
  setSearch: (query, type) ->
    query ?= ''
    type ?= (@_search.type or OutlineEditor.ITEM_PATH_SEARCH)
    return if @_search.query is query and @_search.type is type

    @_search.query = query
    @_search.type = type

    for each in @_searchResults
      eachState = @editorItemState(each)
      if @_searchExpanded[each.id]
        eachState.expanded = false
      eachState.matched = false
      eachState.matchedAncestor = false

    hoisted = @getHoistedItem()
    keywords = null
    error = null

    @_searchResults = []
    @_searchExpanded = {}

    if query
      switch type
        when OutlineEditor.ITEM_PATH_SEARCH
          itemPath = new ItemPath query
          @_search.keywords = itemPath.pathExpressionKeywords
          @_search.error = itemPath.pathExpressionError
          results = ItemPath.evaluate itemPath, hoisted,
            root: hoisted
            attributeShortcuts: @_searchAttributeShortcuts
          for each in results
            @_addSearchResult(each)

        when OutlineEditor.X_PATH_SEARCH
          for each in hoisted.getItemsForXPath(query)
            @_addSearchResult(each)
        else
          console.log "Invalid search type #{type}"

    @outlineEditorElement.updateHoistedItem(null, hoisted)
    @emitter.emit 'did-change-search', @_search
    @_revalidateSelectionRange()
    @_updateBackgroundMessage()

  _addSearchResult: (item) ->
    itemFilterPathItems = @_searchResults
    itemState = @editorItemState(item)
    itemState.matched = true
    itemFilterPathItems.push(item)

    each = item.parent
    while each
      eachState = @editorItemState(each)
      if eachState.matchedAncestor
        return
      else
        unless eachState.expanded
          eachState.expanded = true
          @_searchExpanded[each.id] = true
        eachState.matchedAncestor = true
        itemFilterPathItems.push(each)
      each = each.parent

  ###
  Section: Rendering Items
  ###

  # Public: Render additional text formatting elements in an {Item}'s body
  # text. Intended to support syntax highlighting.
  #
  # ## Examples
  #
  # ```coffee
  # editor.addItemBodyTextRenderer (item, renderElementInBodyTextRange) ->
  #   highlight = 'super!'
  #   while (index = item.bodyText.indexOf highlight, index) isnt -1
  #     renderElementInBodyTextRange 'B', null, index, highlight.length
  #     index += highlight.length
  # ```
  #
  # * `callback` {Function} Text rendering function.
  #   * `item` {Item} being rendered.
  #   * `renderElementInBodyTextRange` {Function} Render text element, accepts the same parameters as {Item::addElementInBodyTextRange}.
  # * `priority` (optional) {Number} Determines rendering order.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to remove the renderer.
  addItemBodyTextRenderer: (callback, priority=0) ->
    @outlineEditorElement.itemRenderer.addTextRenderer callback, priority

  # Public: Render item badges after an {Item}'s body text. Item badges are
  # intended to make visible item attribute values. For example badges are
  # used to display the `data-priority` attribute of an item.
  #
  # ## Examples
  #
  # ```coffee
  # editor.addItemBadgeRenderer (item, renderBadgeElement) ->
  #   if tags = item.getAttribute 'data-tags', true
  #     for each in tags
  #       span = document.createElement 'A'
  #       span.className = 'btag'
  #       span.textContent = each.trim()
  #       renderBadgeElement span
  # ```
  #
  # * `callback` {Function} Badge rendering function.
  #   * `item` {Item} being rendered.
  #   * `renderBadgeElement` {Function} Render passed in badge element.
  #     * `badge` {Element} DOM badge element.
  # * `priority` (optional) {Number} Determines rendering order.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to remove the renderer.
  addItemBadgeRenderer: (callback, priority=0) ->
    @outlineEditorElement.itemRenderer.addBadgeRenderer callback, priority

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

    return true unless @_search.query
    itemState = @editorItemState(item)
    itemState.matched or itemState.matchedAncestor

  # Public: Make the given item visible in the outline, expanding ancestors,
  # removing filter, and unhoisting as needed.
  #
  # - `item` {Item} to make visible.
  makeVisible: (item) ->
    assert.ok(
      item.isInOutline and (item.outline is @outline),
      'Item must be in this outline'
    )

    return if @isVisible item

    hoistedItem = @getHoistedItem()
    while not hoistedItem.contains item
      @unhoist()
      hoistedItem = @getHoistedItem()

    parentsToExpand = []
    eachParent = item.parent
    while eachParent isnt hoistedItem
      if @isCollapsed eachParent
        parentsToExpand.push eachParent
      eachParent = eachParent.parent

    @setExpanded parentsToExpand

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

  getFirstVisibleAncestorOrSelf: (item, hoistedItem) ->
    while item and not @isVisible item, hoistedItem
      item = item.parent
    item

  getVisibleParent: (item, hoistedItem) ->
    if @isVisible(item?.parent, hoistedItem)
      item.parent

  # Public: Returns previous visible sibling {Item} relative to given item.
  #
  # - `item` {Item}
  # - `hoistedItem` (optional) Hoisted item {Item} case to consider.
  getPreviousVisibleSibling: (item, hoistedItem) ->
    item = item?.previousSibling
    while item
      if @isVisible item, hoistedItem
        return item
      item = item.previousSibling

  # Public: Returns next visible sibling {Item} relative to given item.
  #
  # - `item` {Item}
  # - `hoistedItem` (optional) Hoisted item {Item} case to consider.
  getNextVisibleSibling: (item, hoistedItem) ->
    item = item?.nextSibling
    while item
      if @isVisible item, hoistedItem
        return item
      item = item.nextSibling

  # Public: Returns next visible {Item} relative to given item.
  #
  # - `item` {Item}
  # - `hoistedItem` (optional) Hoisted item {Item} case to consider.
  getNextVisibleItem: (item, hoistedItem) ->
    item = item?.nextItem
    while item
      if @isVisible item, hoistedItem
        return item
      item = item.nextItem

  # Public: Returns previous visible {Item} relative to given item.
  #
  # - `item` {Item}
  # - `hoistedItem` (optional) Hoisted item {Item} case to consider.
  getPreviousVisibleItem: (item, hoistedItem) ->
    item = item?.previousItem
    while item
      if @isVisible item, hoistedItem
        return item
      item = item.previousItem

  # Public: Returns first visible child {Item} relative to given item.
  #
  # - `item` {Item}
  # - `hoistedItem` (optional) Hoisted item {Item} case to consider.
  getFirstVisibleChild: (item, hoistedItem) ->
    firstChild = item?.firstChild
    if @isVisible firstChild, hoistedItem
      return firstChild
    @getNextVisibleSibling firstChild, hoistedItem

  # Public: Returns last visible child {Item} relative to given item.
  #
  # - `item` {Item}
  # - `hoistedItem` (optional) Hoisted item {Item} case to consider.
  getLastVisibleChild: (item, hoistedItem) ->
    lastChild = item?.lastChild
    if @isVisible lastChild, hoistedItem
      return lastChild
    @getPreviousVisibleSibling lastChild, hoistedItem

  getLastVisibleDescendantOrSelf: (item, hoistedItem) ->
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
    nextBranch = item?.nextBranch
    if @isVisible nextBranch, hoistedItem
      nextBranch
    else
      @getNextVisibleBranch nextBranch, hoistedItem

  ###
  Section: Focus
  ###

  # Public: Returns {Boolean} indicating if this editor has focus.
  isFocused: ->
    if @_overrideIsFocused
      true
    else
      activeElement = @DOMGetActiveElement()
      outlineEditorElement = @outlineEditorElement
      activeElement and (outlineEditorElement is activeElement or outlineEditorElement.contains(activeElement))

  # Public: Focus this editor.
  focus: ->
    @outlineEditorElement?.focus()

  focusIfNeeded: ->
    @focus() unless @isFocused()

  ###
  Section: Selection
  ###

  # Public: Read-only current {Selection}.
  selection: null
  Object.defineProperty @::, 'selection',
    get: -> @_selection

  # Public: Returns {Boolean} indicating if given item is selected.
  #
  # - `item` {Item}
  isSelected: (item) ->
    @editorItemState(item).selected

  # Public: Returns `true` if is selecting at item level.
  isOutlineMode: ->
    @_selection.isOutlineMode

  # Public: Returns `true` if is selecting at text level.
  isTextMode: ->
    @_selection.isTextMode

  selectionVerticalAnchor: ->
    if @_selectionVerticalAnchor is undefined
      focusRect = @selection.focusClientRect
      @_selectionVerticalAnchor = if focusRect then focusRect.left else 0
    @_selectionVerticalAnchor

  setSelectionVerticalAnchor: (selectionVerticalAnchor) ->
    @_selectionVerticalAnchor = selectionVerticalAnchor

  # Public: Move selection backward.
  moveBackward: ->
    @modifySelectionRange('move', 'backward', (if @isTextMode() then 'character' else 'paragraph'))

  # Public: Move selection backward and modify selection.
  moveBackwardAndModifySelection: ->
    @modifySelectionRange('extend', 'backward', (if @isTextMode() then 'character' else 'paragraph'))

  # Public: Move selection forward.
  moveForward: ->
    @modifySelectionRange('move', 'forward', (if @isTextMode() then 'character' else 'paragraph'))

  # Public: Move selection forward and modify selection.
  moveForwardAndModifySelection: ->
    @modifySelectionRange('extend', 'forward', (if @isTextMode() then 'character' else 'paragraph'))

  # Public: Move selection up.
  moveUp: ->
    @modifySelectionRange('move', 'up', (if @isTextMode() then 'line' else 'paragraph'), true)

  # Public: Move selection up and modify selection.
  moveUpAndModifySelection: ->
    @modifySelectionRange('extend', 'up', (if @isTextMode() then 'line' else 'paragraph'), true)

  # Public: Move selection down.
  moveDown: ->
    @modifySelectionRange('move', 'down', (if @isTextMode() then 'line' else 'paragraph'), true)

  # Public: Move selection down and modify selection.
  moveDownAndModifySelection: ->
    @modifySelectionRange('extend', 'down', (if @isTextMode() then 'line' else 'paragraph'), true)

  # Public: Move selection left.
  moveLeft: ->
    @modifySelectionRange('move', 'left', (if @isTextMode() then 'character' else 'paragraph'))

  # Public: Move selection left and modify selection.
  moveLeftAndModifySelection: ->
    @modifySelectionRange('extend', 'left', (if @isTextMode() then 'character' else 'paragraph'))

  # Public: Move selection to begining of line.
  moveToBeginningOfLine: ->
    @modifySelectionRange('move', 'backward', (if @isTextMode() then 'lineboundary' else 'paragraphboundary'))

  # Public: Move selection to begining of line and modify selection.
  moveToBeginningOfLineAndModifySelection: ->
    @modifySelectionRange('extend', 'backward', (if @isTextMode() then 'lineboundary' else 'paragraphboundary'))

  # Public: Move selection to begining of paragraph.
  moveToBeginningOfParagraph: ->
    @modifySelectionRange('move', 'backward', 'paragraphboundary')

  # Public: Move selection to begining of paragraph and modify selection.
  moveToBeginningOfParagraphAndModifySelection: ->
    @modifySelectionRange('extend', 'backward', 'paragraphboundary')

  # Public: Move selection to next start of paragraph.
  moveParagraphBackward: ->
    if @isTextMode()
      @modifySelectionRange('move', 'backward', 'character')
      @modifySelectionRange('move', 'backward', 'paragraphboundary')
    else
      @modifySelectionRange('move', 'backward', 'paragraph')

  # Public: Move selection to next start of paragraph and modify selection.
  moveParagraphBackwardAndModifySelection: ->
    if @isTextMode()
      @modifySelectionRange('extend', 'backward', 'character')
      @modifySelectionRange('extend', 'backward', 'paragraphboundary')
    else
      @modifySelectionRange('extend', 'backward', 'paragraph')

  # Public: Move selection word left.
  moveWordLeft: ->
    @modifySelectionRange('move', 'left', (if @isTextMode() then 'word' else 'paragraph'))

  # Public: Move selection word left and modify selection.
  moveWordLeftAndModifySelection: ->
    @modifySelectionRange('extend', 'left', (if @isTextMode() then 'word' else 'paragraph'))

  # Public: Move selection right.
  moveRight: ->
    @modifySelectionRange('move', 'right', (if @isTextMode() then 'character' else 'paragraph'))

  # Public: Move selection right and modify selection.
  moveRightAndModifySelection: ->
    @modifySelectionRange('extend', 'right', (if @isTextMode() then 'character' else 'paragraph'))

  # Public: Move selection word right.
  moveWordRight: ->
    @modifySelectionRange('move', 'right', (if @isTextMode() then 'word' else 'paragraph'))

  # Public: Move selection word right and modify selection.
  moveWordRightAndModifySelection: ->
    @modifySelectionRange('extend', 'right', (if @isTextMode() then 'word' else 'paragraph'))

  # Public: Move selection to end of line.
  moveToEndOfLine: ->
    @modifySelectionRange('move', 'forward', 'lineboundary')

  # Public: Move selection to end of line and modify selection.
  moveToEndOfLineAndModifySelection: ->
    @modifySelectionRange('extend', 'forward', 'lineboundary')

  # Public: Move selection to end of paragraph.
  moveToEndOfParagraph: ->
    @modifySelectionRange('move', 'forward', 'paragraphboundary')

  # Public: Move selection to end of paragraph and modify selection.
  moveToEndOfParagraphAndModifySelection: ->
    @modifySelectionRange('extend', 'forward', 'paragraphboundary')

  # Public: Move selection to next end of paragraph.
  moveParagraphForward: ->
    if @isTextMode()
      @modifySelectionRange('move', 'forward', 'character')
      @modifySelectionRange('move', 'forward', 'paragraphboundary')
    else
      @modifySelectionRange('move', 'forward', 'paragraph')

  # Public: Move selection to next end of paragraph and modify selection.
  moveParagraphForwardAndModifySelection: ->
    if @isTextMode()
      @modifySelectionRange('extend', 'forward', 'character')
      @modifySelectionRange('extend', 'forward', 'paragraphboundary')
    else
      @modifySelectionRange('extend', 'forward', 'paragraph')

  # Public: Move selection to begining of document.
  moveToBeginningOfDocument: ->
    @modifySelectionRange('move', 'backward', 'documentboundary')

  # Public: Move selection to begining of document and modify selection.
  moveToBeginningOfDocumentAndModifySelection: ->
    @modifySelectionRange('extend', 'backward', 'documentboundary')

  # Public: Move selection to end of document.
  moveToEndOfDocument: ->
    @modifySelectionRange('move', 'forward', 'documentboundary')

  # Public: Move selection to end of document and modify selection.
  moveToEndOfDocumentAndModifySelection: ->
    @modifySelectionRange('extend', 'forward', 'documentboundary')

  extendSelectionRangeToItemBoundaries: ->
    @moveSelectionRange(
      @selection.focusItem,
      undefined,
      @selection.anchorItem,
      undefined
    )

  extendSelectionRangeToSentanceBoundaries: ->
    @extendSelectionRangeToBoundary 'sentenceboundary'

  extendSelectionRangeToLineBoundaries: ->
    @extendSelectionRangeToBoundary 'lineboundary'

  extendSelectionRangeToWordBoundaries: ->
    @extendSelectionRangeToBoundary 'word'

  extendSelectionRangeToBoundary: (boundary) ->
    selection = @selection
    startItem = selection.startItem
    endItem = selection.endItem

    originalStart = selection.startOffset
    startOffset = Selection.nextSelectionIndexFrom startItem, selection.startOffset, 'backward', boundary
    probeForward = Selection.nextSelectionIndexFrom startItem, startOffset, 'forward', boundary
    if probeForward < originalStart
      startOffset = originalStart

    originalEnd = selection.endOffset
    endOffset = Selection.nextSelectionIndexFrom endItem, selection.endOffset, 'forward', boundary
    probeBackward = Selection.nextSelectionIndexFrom startItem, endOffset, 'backward', boundary
    if probeBackward > originalEnd
      endOffset = originalEnd

    if originalStart is startOffset and originalEnd is endOffset
      endOffset++

    @moveSelectionRange endItem, endOffset, startItem, startOffset

  # Public: Set a new {Selection}.
  #
  # - `focusItem` Selection focus {Item}
  # - `focusOffset` (optional) Selection focus offset index. Or `undefined`
  #    when selecting at item level.
  # - `anchorItem` (optional) Selection anchor {Item}
  # - `anchorOffset` (optional) Selection anchor offset index. Or `undefined`
  #    when selecting at item level.
  moveSelectionRange: (focusItem, focusOffset, anchorItem, anchorOffset, selectionAffinity) ->
    @_textModeExtendingFromSnapbackRange = null
    @_updateSelectionIfNeeded(@createSelection(focusItem, focusOffset, anchorItem, anchorOffset, selectionAffinity))

  # Public: Extend the {Selection} to a new focus item/offset.
  #
  # - `focusItem` Selection focus {Item}
  # - `focusOffset` (optional) Selection focus offset index. Or `undefined`
  #    when selecting at item level.
  extendSelectionRange: (focusItem, focusOffset, selectionAffinity) ->
    checkForTextModeSnapback = false
    if @selection.isTextMode
      @_textModeExtendingFromSnapbackRange = @selection
    else
      checkForTextModeSnapback = true
    @_updateSelectionIfNeeded(@_selection.selectionByExtending(focusItem, focusOffset, selectionAffinity), checkForTextModeSnapback)

  modifySelectionRange: (alter, direction, granularity, maintainVertialAnchor) ->
    saved = @selectionVerticalAnchor()
    checkForTextModeSnapback = false

    if alter is 'extend'
      selectionRange = @selection
      if selectionRange.isTextMode
        @_textModeExtendingFromSnapbackRange = selectionRange
      else
        checkForTextModeSnapback = true
    else
      @_textModeExtendingFromSnapbackRange = null

    @_updateSelectionIfNeeded(@_selection.selectionByModifying(alter, direction, granularity), checkForTextModeSnapback)

    if maintainVertialAnchor
      @setSelectionVerticalAnchor(saved)

  # Public: Select all children of the current {::hoistedItem} item.
  selectAll: ->
    if @isOutlineMode()
      @outlineEditorElement.disableScrolling()
      @moveSelectionRange(@getFirstVisibleItem(), undefined, @getLastVisibleItem(), undefined)
      @outlineEditorElement.enableScrolling()
    else
      selectionRange = @selection
      item = selectionRange.anchorItem
      startOffset = selectionRange.startOffset
      endOffset = selectionRange.endOffset

      if item
        textLength = item.bodyText.length
        if startOffset is 0 and endOffset is textLength
          @moveSelectionRange(item, undefined, item, undefined)
        else
          @moveSelectionRange(item, 0, item, textLength)

  createSelection: (focusItem, focusOffset, anchorItem, anchorOffset, selectionAffinity) ->
    new Selection(this, focusItem, focusOffset, anchorItem, anchorOffset, selectionAffinity)

  _revalidateSelectionRange: ->
    @_updateSelectionIfNeeded(@_selection.selectionByRevalidating())

  _updateSelectionIfNeeded: (newSelection, checkForTextModeSnapback) ->
    currentSelection = @selection
    outlineEditorElement = @outlineEditorElement
    isFocused = @isFocused()

    if checkForTextModeSnapback
      if not newSelection.isTextMode and newSelection.focusItem is newSelection.anchorItem and @_textModeExtendingFromSnapbackRange
        newSelection = @_textModeExtendingFromSnapbackRange
        @_textModeExtendingFromSnapbackRange = null

    if not currentSelection.equals(newSelection)
      wasSelectedMarker = 'marker'
      newRangeItems = newSelection.items
      currentRangeItems = currentSelection.items
      @_selection = newSelection

      for each in currentRangeItems
        @editorItemState(each).selected = wasSelectedMarker

      for each in newRangeItems
        state = @editorItemState(each)
        if state.selected is wasSelectedMarker
          state.selected = true
        else
          state.selected = true
          outlineEditorElement.updateItemClass(each)

      for each in currentRangeItems
        state = @editorItemState(each)
        if state.selected is wasSelectedMarker
          state.selected = false
          outlineEditorElement.updateItemClass(each)

      if currentSelection.isTextMode isnt newSelection.isTextMode
        # Bit of overrendering... but need to handle item class case
        # .selectedItemWithTextSelection. So if selection has changed
        # from/to text mode then rerender all the endpoints.
        if currentSelection.isValid
          outlineEditorElement.updateItemClass(currentSelection.focusItem)
          outlineEditorElement.updateItemClass(currentSelection.anchorItem)

        if newSelection.isValid
          outlineEditorElement.updateItemClass(newSelection.focusItem)
          outlineEditorElement.updateItemClass(newSelection.anchorItem)

      currentSelection = newSelection

      if newSelection.focusItem
        @scrollToItemIfNeeded newSelection.focusItem, newSelection.focusOffset, true

      @setSelectionVerticalAnchor(undefined)

    if currentSelection.isTextMode
      focusItem = currentSelection.focusItem
      formattingOffset = currentSelection.anchorOffset

      if not currentSelection.isCollapsed
        formattingOffset = currentSelection.startOffset + 1

      if formattingOffset > 0
        @setTypingFormattingTags(focusItem.getElementsAtBodyTextIndex(formattingOffset - 1))
      else
        @setTypingFormattingTags(focusItem.getElementsAtBodyTextIndex(formattingOffset))
    else
      @setTypingFormattingTags({})

    if isFocused
      @focus()

    classList = outlineEditorElement.classList
    if currentSelection.isTextMode
      classList.remove('outlineMode')
      classList.add('textMode')
    else
      classList.remove('textMode')
      classList.add('outlineMode')

    @emitter.emit 'did-change-selection', currentSelection

  ###
  Section: Insert Items
  ###

  # Public: Insert text at current selection. If is in text selection mode the
  # current text selection will get replaced with this text. If in item
  # selection mode a new item will get inserted.
  #
  # - `text` Text {String} or {AttributedString} to insert
  insertText: (insertedText) ->
    selectionRange = @selection
    undoManager = @outline.undoManager

    if selectionRange.isTextMode
      if not (insertedText instanceof AttributedString)
        insertedText = new AttributedString(insertedText)
        insertedText.addAttributesInRange(@getTypingFormattingTags(), 0, -1)

      focusItem = selectionRange.focusItem
      startOffset = selectionRange.startOffset
      endOffset = selectionRange.endOffset

      focusItem.replaceBodyTextInRange(insertedText, startOffset, endOffset - startOffset)
      @moveSelectionRange(focusItem, startOffset + insertedText.length)
    else
      @moveSelectionRange(@insertItem(insertedText))

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

  insertItemAbove: (text) ->
    @insertItem(text, true)

  insertItemBelow: (text) ->
    @insertItem(text)

  indent: ->
    @moveItemsRight()

  outdent: ->
    @moveItemsLeft()

  insertTabIgnoringFieldEditor: ->
    @insertText('\t')

  getTypingFormattingTags: ->
    @_textModeTypingFormattingTags

  setTypingFormattingTags: (typingFormattingTags) ->
    if typingFormattingTags
      typingFormattingTags = _.clone(typingFormattingTags)
    @_textModeTypingFormattingTags = typingFormattingTags or {}

  toggleTypingFormattingTag: (tagName, tagValue) ->
    typingFormattingTags = @getTypingFormattingTags()
    if typingFormattingTags[tagName] isnt undefined
      delete typingFormattingTags[tagName]
    else
      typingFormattingTags[tagName] = tagValue or null
    @setTypingFormattingTags typingFormattingTags

  ###
  Section: Move Items
  ###

  moveItemsUp: ->
    @_moveItemsInDirection('up')

  moveItemsDown: ->
    @_moveItemsInDirection('down')

  moveItemsLeft: ->
    @_moveItemsInDirection('left')

  moveItemsRight: ->
    @_moveItemsInDirection('right')

  _moveItemsInDirection: (direction) ->
    selectedItems = @selection.itemsCommonAncestors
    if selectedItems.length > 0
      startItem = selectedItems[0]
      newNextSibling
      newParent

      if direction is 'up'
        newNextSibling  = @getPreviousVisibleSibling(startItem)
        if newNextSibling
          newParent = startItem.parent
      else if direction is 'down'
        endItem = selectedItems[selectedItems.length - 1]
        newNextSibling = @getNextVisibleSibling(endItem)
        if newNextSibling
          newParent = endItem.parent
          newNextSibling = @getNextVisibleSibling(newNextSibling)
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
        @moveItems(selectedItems, newParent, newNextSibling)

  promoteChildItems: ->
    selectedItems = @selection.itemsCommonAncestors
    if selectedItems.length > 0
      undoManager = @outline.undoManager
      undoManager.beginUndoGrouping()
      for each in selectedItems
        @moveItems(each.children, each.parent, each.nextSibling)
      undoManager.endUndoGrouping()
      undoManager.setActionName('Promote Children')

  demoteTrailingSiblingItems: ->
    selectedItems = @selection.itemsCommonAncestors
    item = selectedItems[0]

    if item
      trailingSiblings = []
      each = item.nextSibling

      while each
        trailingSiblings.push(each)
        each = each.nextSibling

      if trailingSiblings.length > 0
        @moveItems(trailingSiblings, item, null)
        @outline.undoManager.setActionName('Demote Siblings')

  groupItems: ->
    selectedItems = @selection.itemsCommonAncestors
    if selectedItems.length > 0
      first = selectedItems[0]
      group = @outline.createItem ''

      undoManager = @outline.undoManager
      undoManager.beginUndoGrouping()

      first.parent.insertChildBefore group, first
      @moveSelectionRange group, 0
      @moveItems selectedItems, group

      undoManager.endUndoGrouping()
      undoManager.setActionName('Group Items')

  moveItems: (items, newParent, newNextSibling, startOffset) ->
    undoManager = newParent.outline.undoManager
    undoManager.beginUndoGrouping()
    @outlineEditorElement.animateMoveItems(items, newParent, newNextSibling, startOffset)
    undoManager.endUndoGrouping()
    undoManager.setActionName('Move Items')

  ###
  Section: Delete Items
  ###

  deleteBackward: ->
    @delete('backward', 'character')

  deleteBackwardByDecomposingPreviousCharacter: ->
    @delete('backward', 'character')

  deleteWordBackward: ->
    @delete('backward', 'word')

  deleteToBeginningOfLine: ->
    @delete('backward', 'lineboundary')

  deleteToEndOfParagraph: ->
    @delete('forward', 'paragraphboundary')

  deleteForward: ->
    @delete('forward', 'character')

  deleteWordForward: ->
    @delete('forward', 'word')

  deleteItemsBackward: ->
    @delete('backward', 'item')

  deleteItemsForward: ->
    @delete('forward', 'item')

  delete: (direction, granularity) ->
    outline = @outline
    selectionRange = @selection
    undoManager = outline.undoManager
    outlineEditorElement = @outlineEditorElement

    if selectionRange.isTextMode
      if selectionRange.isCollapsed
        @modifySelectionRange('extend', direction, granularity)
        selectionRange = @selection

      startItem = selectionRange.startItem
      startOffset = selectionRange.startOffset
      endItem = selectionRange.endItem
      endOffset = selectionRange.endOffset

      if not selectionRange.isCollapsed
        undoManager.beginUndoGrouping()
        outline.beginUpdates()

        if 0 is startOffset and startItem isnt endItem and startItem is endItem.previousSibling and startItem.bodyText.length is 0
          @moveSelectionRange(endItem, 0)
          endItem.replaceBodyTextInRange('', 0, endOffset)
          for each in selectionRange.items[...-1]
            each.removeFromParent()
        else
          @moveSelectionRange(startItem, startOffset)
          if startItem is endItem
            startItem.replaceBodyTextInRange('', startOffset, endOffset - startOffset)
          else
            startItem.replaceBodyTextInRange(endItem.getAttributedBodyTextSubstring(endOffset, -1), startOffset, -1)
            startItem.appendChildren(endItem.children)
            for each in selectionRange.items[1...]
              each.removeFromParent()

        outline.endUpdates()
        undoManager.endUndoGrouping()
        undoManager.setActionName('Delete')
    else if selectionRange.isOutlineMode
      selectedItems = selectionRange.itemsCommonAncestors
      if selectedItems.length > 0
        startItem = selectedItems[0]
        endItem = selectedItems[selectedItems.length - 1]
        parent = startItem.parent
        nextSibling = @getNextVisibleSibling(endItem)
        previousSibling = @getPreviousVisibleItem(startItem)
        nextSelection = null

        if Selection.isUpstreamDirection(direction)
          nextSelection = previousSibling or nextSibling or parent
        else
          nextSelection = nextSibling or previousSibling or parent

        undoManager.beginUndoGrouping()
        outline.beginUpdates()

        if nextSelection
          @moveSelectionRange(nextSelection)

        outline.removeItemsFromParents(selectedItems)
        outline.endUpdates()
        undoManager.endUndoGrouping()
        undoManager.setActionName('Delete')

  ###
  Section: Pasteboard
  ###

  copySelection: (dataTransfer) ->
    selectionRange = @selection

    if not selectionRange.isCollapsed
      if selectionRange.isOutlineMode
        items = selectionRange.itemsCommonAncestors
        ItemSerializer.writeItems(items, this, dataTransfer)
      else if selectionRange.isTextMode
        focusItem = selectionRange.focusItem
        startOffset = selectionRange.startOffset
        endOffset = selectionRange.endOffset
        selectedText = focusItem.getAttributedBodyTextSubstring(startOffset, endOffset - startOffset)
        p = document.createElement('P')
        p.appendChild(ItemBodyEncoder.attributedStringToDocumentFragment(selectedText, document))
        dataTransfer.setData('text/plain', selectedText.string())
        dataTransfer.setData('text/html', p.innerHTML)

  cutSelection: (dataTransfer) ->
    selectionRange = @selection
    if selectionRange.isValid
      if not selectionRange.isCollapsed
        @copySelection(dataTransfer)
        @delete()

  pasteToSelection: (dataTransfer) ->
    selectionRange = @selection
    items = ItemSerializer.readItems(this, dataTransfer)

    if items.itemFragmentString
      @insertText(items.itemFragmentString)
    else if items.length
      parent = @getHoistedItem()
      insertBefore = null

      if selectionRange.isValid
        endItem = selectionRange.endItem
        if @isExpanded(endItem)
          parent = endItem
          insertBefore = endItem.firstChild
        else
          parent = endItem.parent
          insertBefore = endItem.nextSibling

      parent.insertChildrenBefore(items, insertBefore)
      @moveSelectionRange(items[0], undefined, items[items.length - 1], undefined)

  ###
  Section: Formatting
  ###

  toggleFormattingTag: (tagName, attributes={}) ->
    startItem = @selection.startItem

    if @selection.isCollapsed
      @toggleTypingFormattingTag(tagName)
    else if startItem
      tagAttributes = startItem.getElementAtBodyTextIndex(tagName, @selection.startOffset or 0)
      addingTag = tagAttributes is undefined

      @_transformSelectedText (eachItem, start, end) ->
        if (addingTag)
          eachItem.addElementInBodyTextRange(tagName, attributes, start, end - start)
        else
          eachItem.removeElementInBodyTextRange(tagName, start, end - start)

  clearFormatting: ->
    selection = @selection
    if selection.isCollapsed
      longestRange = {}
      focusItem = selection.focusItem
      focusOffset = selection.focusOffset
      focusTextLength = focusItem.bodyText.length

      if focusTextLength is 0
        return

      if focusOffset is focusTextLength
        focusOffset--

      elements = focusItem.getElementsAtBodyTextIndex(focusOffset, null, longestRange)
      unless Object.keys(elements).length
        return

      @moveSelectionRange(focusItem, longestRange.location, focusItem, longestRange.end)

    @_transformSelectedText (eachItem, start, end) ->
      string = new AttributedString eachItem.bodyText.substring(start, end)
      eachItem.replaceBodyTextInRange string, start, end - start

  upperCase: ->
    @_transformSelectedText (item, start, end) ->
      item.replaceBodyTextInRange(item.bodyText.substring(start, end).toUpperCase(), start, end - start)

  lowerCase: ->
    @_transformSelectedText (item, start, end) ->
      item.replaceBodyTextInRange(item.bodyText.substring(start, end).toLowerCase(), start, end - start)

  _transformSelectedText: (transform) ->
    selectionRange = @selection
    outline = @outline
    undoManager = outline.undoManager
    outline.beginUpdates()
    undoManager.beginUndoGrouping()

    if selectionRange.isTextMode
      transform(selectionRange.startItem, selectionRange.startOffset, selectionRange.endOffset)
    else
      for each in selectionRange.items
        transform(each, 0, each.bodyText.length)

    undoManager.endUndoGrouping()
    outline.endUpdates()

  ###
  Section: Drag and Drop
  ###

  draggedItem: ->
    @outline._draggedItemHack

  dropEffect: ->
    @_dragState.dropEffect

  dropParentItem: ->
    @_dragState.dropParentItem

  dropInsertBeforeItem: ->
    @_dragState.dropInsertBeforeItem

  dropInsertAfterItem: ->
    @_dragState.dropInsertAfterItem

  _refreshIfDifferent: (item1, item2) ->
    if item1 isnt item2
      outlineEditorElement = @outlineEditorElement
      outlineEditorElement.updateItemClass(item1)
      outlineEditorElement.updateItemClass(item2)

  setDragState: (state) ->
    if state.dropParentItem and not state.dropInsertBeforeItem
      state.dropInsertAfterItem = @getLastVisibleChild(state.dropParentItem)

    oldState = @_dragState
    @outline._draggedItemHack = state.draggedItem
    @_dragState = state

    @_refreshIfDifferent(oldState.draggedItem, state.draggedItem)
    @_refreshIfDifferent(oldState.dropParentItem, state.dropParentItem)
    @_refreshIfDifferent(oldState.dropInsertBeforeItem, state.dropInsertBeforeItem)
    @_refreshIfDifferent(oldState.dropInsertAfterItem, state.dropInsertAfterItem)

  OutlineEditor::debouncedSetDragState = rafdebounce(OutlineEditor::setDragState)

  ###
  Section: Undo
  ###

  # Public: Undo the last change.
  undo: ->
    @outline.undoManager.undo()

  # Public: Redo the last change.
  redo: ->
    @outline.undoManager.redo()

  didOpenUndoGroup: (undoManager) ->
    if not undoManager.isUndoing and not undoManager.isRedoing
      undoManager.setUndoGroupMetadata('undoSelection', @selection)

  didReopenUndoGroup: (undoManager) ->

  willUndo: (undoManager, undoGroupMetadata) ->
    @_overrideIsFocused = @isFocused()
    undoManager.setUndoGroupMetadata('redoSelection', @selection)

  didUndo: (undoManager, undoGroupMetadata) ->
    selectionRange = undoGroupMetadata.undoSelection
    if selectionRange
      @moveSelectionRange(selectionRange)
    @_overrideIsFocused = false

  willRedo: (undoManager, undoGroupMetadata) ->
    @_overrideIsFocused = @isFocused()

  didRedo: (undoManager, undoGroupMetadata) ->
    selectionRange = undoGroupMetadata.redoSelection
    if selectionRange
      @moveSelectionRange(selectionRange)
    @_overrideIsFocused = false

  ###
  Section: Scrolling
  ###

  scrollToBeginningOfDocument: (e) ->
    @outlineEditorElement.scrollToBeginningOfDocument()

  scrollToEndOfDocument: (e) ->
    @outlineEditorElement.scrollToEndOfDocument()

  scrollPageUp: (e) ->
    @outlineEditorElement.scrollPageUp()

  pageUpAndModifySelection: (e) ->
    # Extend focus up 1 page

  pageUp: (e) ->
    # Move focus up 1 page

  scrollPageDown: (e) ->
    @outlineEditorElement.scrollPageDown()

  pageDownAndModifySelection: (e) ->
    # Extend focus down 1 page

  pageDown: (e) ->
    # Move focus down 1 page

  scrollToOffsetRange: (startOffset, endOffset, align) ->
    @outlineEditorElement.scrollToOffsetRange(startOffset, endOffset, align)

  scrollToOffsetRangeIfNeeded: (startOffset, endOffset, center) ->
    @outlineEditorElement.scrollToOffsetRangeIfNeeded(startOffset, endOffset, center)

  scrollToItem: (item, offset, align) ->
    @outlineEditorElement.scrollToItem(item, offset, align)

  scrollToItemIfNeeded: (item, offset, center) ->
    @outlineEditorElement.scrollToItemIfNeeded(item, offset, center)

  centerSelectionInVisibleArea: ->

  ###
  Section: Geometry
  ###

  getClientRectForItemOffset: (item, offset) ->
    @outlineEditorElement.getClientRectForItemOffset item, offset

  getClientRectForItemRange: (startItem, startOffset, endItem, endOffset) ->
    @outlineEditorElement.getClientRectForItemRange startItem, startOffset, endItem, endOffset

  renderedLIForItem: (item) ->
    @outlineEditorElement.renderedLIForItem(item)

  ###
  Section: File Details
  ###

  getTitle: ->
    if sessionPath = @getPath()
      path.basename(sessionPath)
    else
      'Untitled'

  getLongTitle: ->
    if sessionPath = @getPath()
      fileName = path.basename(sessionPath)
      directory = atom.project.relativize(path.dirname(sessionPath))
      directory = if directory.length > 0 then directory else path.basename(path.dirname(sessionPath))
      "#{fileName} - #{directory}"
    else
      'Untitled'

  getURI: ->
    @outline.getUri()

  getPath: ->
    @outline.getPath()

  isModified: ->
    @outline.isModified()

  isEmpty: ->
    @outline.isEmpty()

  copyPathToClipboard: ->
    if filePath = @getPath()
      atom.clipboard.write(filePath)

  save: ->
    @outline.save(this)

  saveAs: (filePath) ->
    @outline.saveAs(filePath, this)

  shouldPromptToSave: ->
    @isModified() and not @outline.hasMultipleEditors()

  ###
  Section: Util
  ###

  # Public: Given a view DOM element find and return the {OutlineEditor} that
  # contains it. For example this is useful when doing event handling. If you
  # detect a click on some element you use this method to find the associated
  # editor.
  #
  # - `element` DOM element.
  #
  # Returns {OutlineEditor}.
  @findOutlineEditor: (element) ->
    OutlineEditorElement.findOutlineEditor element

  editorItemState: (item) ->
    if item
      editorItemStateKey = @id + 'editor-state'
      unless editorItemState = item.getUserData editorItemStateKey
        editorItemState = new OutlineEditorItemState
        item.setUserData editorItemStateKey, editorItemState
      editorItemState

  #OutlineEditor::DOMGetElementById(id) {
  #  let shadowRoot = this._shadowRoot;
  #  if (shadowRoot) {
  #    return shadowRoot.getElementById(id);
  #  }
  #  return document.getElementById(id);
  #};

  DOMGetSelection: (id) ->
    #let shadowRoot = this._shadowRoot;
    #if (shadowRoot) {
    #  return shadowRoot.getSelection(id);
    #}
    document.getSelection(id)

  DOMGetActiveElement: (id) ->
    #let shadowRoot = this._shadowRoot;
    #if (shadowRoot) {
    #  return shadowRoot.activeElement;
    #}
    document.activeElement

  DOMElementFromPoint: (clientX, clientY) ->
    root = @_shadowRoot or document
    root.elementFromPoint(clientX, clientY)

  DOMCaretPositionFromPoint: (clientX, clientY) ->
    # NOTE, this code fails under shadow DOM
    root = @_shadowRoot or document
    result

    if root.caretPositionFromPoint
      result = root.caretPositionFromPoint(clientX, clientY)
      result.range = document.createRange()
      result.range.setStart(result.offsetItem, result.offset)
    # WebKit
    else if root.caretRangeFromPoint
      range = root.caretRangeFromPoint(clientX, clientY)
      if range
        result =
          offsetItem: range.startContainer
          offset: range.startOffset
          range: range

    result
