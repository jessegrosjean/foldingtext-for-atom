# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

{File, Emitter, Disposable, CompositeDisposable} = require 'atom'
ItemSerializer = require './item-serializer'
AttributedString = require './attributed-string'
UndoManager = require './undo-manager'
Constants = require './constants'
ItemPath = require './item-path'
Mutation = require './mutation'
urls = require './util/urls'
shortid = require './shortid'
_ = require 'underscore-plus'
assert = require 'assert'
Item = require './item'
path = require 'path'
fs = require 'fs'
Q = require 'q'

# Essential: A mutable outline of {Item}s.
#
# Use outlines to create new items, find existing items, and watch for changes
# in items. Outlines also coordinate loading and saving items.
#
# Internally a {HTMLDocument} is used to store the underlying outline data.
# You should never modify the content of this HTMLDocument directly, but you
# can query it using {::evaluateXPath}. The structure of this document is
# described in [Birch Markup Language](http://jessegrosjean.gitbooks.io
# /birch-for-atom-user-s-guide/content/appendix_b_file_format.html).
#
# ## Examples
#
# Group multiple changes:
#
# ```coffeescript
# outline.beginChanges()
# root = outline.root
# root.appendChild outline.createItem()
# root.appendChild outline.createItem()
# root.firstChild.bodyString = 'first'
# root.lastChild.bodyString = 'last'
# outline.endChanges()
# ```
#
# Watch for outline changes:
#
# ```coffeescript
# disposable = outline.onDidChange (mutation) ->
#   switch mutation.type
#     when Mutation.ATTRIBUTE_CHANGED
#       console.log mutation.attributeName
#     when Mutation.BODY_CHANGED
#       console.log mutation.target.bodyString
#     when Mutation.CHILDREN_CHANGED
#       console.log mutation.addedItems
#       console.log mutation.removedItems
# ```
#
# Use XPath to list all items with bold text:
#
# ```coffeescript
# for each in outline.getItemsForXPath('//b')
#   console.log each
# ```
class Outline

  root: null
  idsToItems: null
  refcount: 0
  changeCount: 0
  undoSubscriptions: null
  changingCount: 0
  changesCallbacks: null
  coalescingMutation: null
  stoppedChangingDelay: 300
  stoppedChangingTimeout: null
  file: null
  fileMimeType: null
  fileConflict: false
  fileSubscriptions: null
  loadOptions: null

  ###
  Section: Construction
  ###

  # Public: Create a new outline.
  constructor: (options) ->
    @id = shortid()
    @idsToItems = new Map()
    @attributedString = new AttributedString
    @root = @createItem '', Constants.RootID
    @root.isInOutline = true
    @undoManager = undoManager = new UndoManager
    @emitter = new Emitter

    @syncingToAttributes = 0
    @syncingToBody = 0
    @syncRules = null

    @loaded = false
    @loadOptions = {}

    @undoSubscriptions = new CompositeDisposable
    @undoSubscriptions.add undoManager.onDidCloseUndoGroup (group) =>
      if not undoManager.isUndoing and not undoManager.isRedoing and group.length > 0
        @updateChangeCount(Outline.ChangeDone)
        @scheduleModifiedEvents()
    @undoSubscriptions.add undoManager.onWillUndo =>
      @breakUndoCoalescing()
    @undoSubscriptions.add undoManager.onDidUndo =>
      @updateChangeCount(Outline.ChangeUndone)
      @breakUndoCoalescing()
      @scheduleModifiedEvents()
    @undoSubscriptions.add undoManager.onWillRedo =>
      @breakUndoCoalescing()
    @undoSubscriptions.add undoManager.onDidRedo =>
      @updateChangeCount(Outline.ChangeRedone)
      @breakUndoCoalescing()
      @scheduleModifiedEvents()

    @nativeDocument = options?.nativeDocument
    @setPath(options.filePath) if options?.filePath
    @load() if options?.load

  ###
  Section: Finding Outlines
  ###

  # Public: Read-only unique (not persistent) {String} outline ID.
  id: null

  @outlines = []

  # Retrieves all open {Outlines}s.
  #
  # Returns an {Array} of {Outlines}s.
  @getOutlines: ->
    @outlines.slice()

  # Public: Returns existing {Outline} with the given outline id.
  #
  # - `id` {String} outline id.
  @getOutlineForID: (id) ->
    for each in @outlines
      if each.id is id
        return each

  # Given a file path, this retrieves or creates a new {Outline}.
  #
  # - `filePath` {String} outline file path.
  # - `createIfNeeded` (optional) {Boolean} create and return a new outline if can't find match.
  #
  # Returns a promise that resolves to the {Outline}.
  @getOutlineForPath: (filePath, createIfNeeded=true) ->
    absoluteFilePath = atom.project.resolvePath(filePath)

    for each in @outlines
      if each.getPath() is absoluteFilePath
        return Q(each)

    if createIfNeeded
      Q(@buildOutline(absoluteFilePath))

  @getOutlineForPathSync: (filePath, createIfNeeded=true) ->
    absoluteFilePath = atom.project.resolvePath(filePath)

    for each in @outlines
      if each.getPath() is absoluteFilePath
        return each

    if createIfNeeded
      @buildOutlineSync(absoluteFilePath)

  @buildOutline: (absoluteFilePath) ->
    outline = new Outline({filePath: absoluteFilePath})
    @addOutline(outline)
    outline.load()
      .then((outline) -> outline)
      .catch (error) ->
        atom.confirm
          message: "Could not open '#{outline.getTitle()}'"
          detailedMessage: "While trying to load encountered the following problem: #{error.name} – #{error.message}"
        outline.destroy()

  @buildOutlineSync: (absoluteFilePath) ->
    outline = new Outline({filePath: absoluteFilePath})
    @addOutline(outline)
    outline.loadSync()
    outline

  @addOutline: (outline, options={}) ->
    @addOutlineAtIndex(outline, @outlines.length, options)
    @subscribeToOutline(outline)

  @addOutlineAtIndex: (outline, index, options={}) ->
    @outlines.splice(index, 0, outline)
    @subscribeToOutline(outline)
    outline

  @removeOutline: (outline) ->
    index = @outlines.indexOf(outline)
    @removeOutlineAtIndex(index) unless index is -1

  @removeOutlineAtIndex: (index, options={}) ->
    [outline] = @outlines.splice(index, 1)
    outline?.destroy()

  @subscribeToOutline: (outline) ->
    outline.onDidDestroy => @removeOutline(outline)
    outline.onWillThrowWatchError ({error, handle}) ->
      handle()
      atom.notifications.addWarning """
        Unable to read file after file `#{error.eventType}` event.
        Make sure you have permission to access `#{outline.getPath()}`.
        """,
        detail: error.message
        dismissable: true

  ###
  Section: Event Subscription
  ###

  # Public: Invoke the given callback when the outline begins a series of
  # changes.
  #
  # * `callback` {Function} to be called when the outline begins updating.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidBeginChanges: (callback) ->
    @emitter.on 'did-begin-changes', callback

  # Public: Invoke the given callback _before_ the outline changes.
  #
  # * `callback` {Function} to be called when the outline will change.
  #   * `mutation` {Mutation} describing the change.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onWillChange: (callback) ->
    @emitter.on 'will-change', callback

  # Public: Invoke the given callback when the outline changes.
  #
  # See {Outline} Examples for an example of subscribing to this event.
  #
  # - `callback` {Function} to be called when the outline changes.
  #   - `mutation` {Mutation} describing the changes.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChange: (callback) ->
    @emitter.on 'did-change', callback

  # Public: Invoke the given callback when the outline ends a series of
  # changes.
  #
  # * `callback` {Function} to be called when the outline begins updating.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidEndChanges: (callback) ->
    @emitter.on 'did-end-changes', callback

  # Public: Invoke the given callback when the in-memory contents of the
  # outline become in conflict with the contents of the file on disk.
  #
  # - `callback` {Function} to be called when the outline enters conflict.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidConflict: (callback) ->
    @emitter.on 'did-conflict', callback

  # Public: Invoke the given callback when the value of {::isModified} changes.
  #
  # - `callback` {Function} to be called when {::isModified} changes.
  #   - `modified` {Boolean} indicating whether the outline is modified.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeModified: (callback) ->
    @emitter.on 'did-change-modified', callback

  # Public: Invoke the given callback when the value of {::getPath} changes.
  #
  # - `callback` {Function} to be called when the path changes.
  #   - `path` {String} representing the outline's current path on disk.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangePath: (callback) ->
    @emitter.on 'did-change-path', callback

  # Public: Invoke the given callback before the outline is saved to disk.
  #
  # - `callback` {Function} to be called before the outline is saved.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onWillSave: (callback) ->
    @emitter.on 'will-save', callback

  # Public: Invoke the given callback after the outline is saved to disk.
  #
  # - `callback` {Function} to be called after the outline is saved.
  #   - `event` {Object} with the following keys:
  #     - `path` The path to which the outline was saved.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidSave: (callback) ->
    @emitter.on 'did-save', callback

  # Public: Invoke the given callback after the file backing the outline is
  # deleted.
  #
  # * `callback` {Function} to be called after the outline is deleted.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDelete: (callback) ->
    @emitter.on 'did-delete', callback

  # Public: Invoke the given callback before the outline is reloaded from the
  # contents of its file on disk.
  #
  # - `callback` {Function} to be called before the outline is reloaded.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onWillReload: (callback) ->
    @emitter.on 'will-reload', callback

  # Public: Invoke the given callback after the outline is reloaded from the
  # contents of its file on disk.
  #
  # - `callback` {Function} to be called after the outline is reloaded.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidReload: (callback) ->
    @emitter.on 'did-reload', callback

  # Public: Invoke the given callback when the outline is destroyed.
  #
  # - `callback` {Function} to be called when the outline is destroyed.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  # Public: Invoke the given callback when there is an error in watching the
  # file.
  #
  # * `callback` {Function} callback
  #   * `errorObject` {Object}
  #     * `error` {Object} the error object
  #     * `handle` {Function} call this to indicate you have handled the error.
  #       The error will not be thrown if this function is called.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onWillThrowWatchError: (callback) ->
    @emitter.on 'will-throw-watch-error', callback

  getStoppedChangingDelay: -> @stoppedChangingDelay

  ###
  Section: Reading Items
  ###

  isEmpty: ->
    firstChild = @root.firstChild
    not firstChild or
        (not firstChild.nextItem and
        firstChild.bodyString.length is 0)

  # Public: Returns an {Array} of all {Item}s in the outline (except the
  # root) in outline order.
  getItems: ->
    @root.descendants

  # Public: Returns {Item} for given id.
  #
  # - `id` {String} id.
  getItemForID: (id) ->
    @idsToItems.get(id)

  # Public: Returns {Array} of {Item}s for given {Array} of ids.
  #
  # - `ids` {Array} of ids.
  getItemsForIDs: (ids) ->
    return [] unless ids

    items = []
    for each in ids
      each = @getItemForID each
      if each
        items.push each
    items

  getAttributeNames: (autoIncludeNames=[]) ->
    attributes = new Set()

    for each in autoIncludeNames
      attributes.add(each)

    for each in @root.descendants
      for eachAttributeName in Object.keys(each.attributes)
        attributes.add(eachAttributeName)

    attributesArray = []
    attributes.forEach (each) ->
      attributesArray.push(each)
    attributesArray.sort()
    attributesArray

  ###
  Section: Creating Items
  ###

  # Public: Create a new item. The new item is owned by this outline, but is
  # not yet inserted into it so it won't be visible until you insert it.
  #
  # - `text` (optional) {String} or {AttributedString}.
  createItem: (text, id, remapIDCallback) ->
    new Item(@, text, id, remapIDCallback)

  cloneItem: (item, deep=true, remapIDCallback) ->
    assert.ok(not item.isRoot, 'Can not clone root')
    assert.ok(item.outline is @, 'Item must be owned by this outline')

    clonedItem = @createItem(item.bodyAttributedString.clone())

    if item.attributes
      clonedItem.attributes = _.clone(item.attributes)
    if item.userData
      clonedItem.userData = _.clone(item.userData)

    if deep and eachChild = item.firstChild
      children = []
      while eachChild
        children.push(@cloneItem(eachChild, deep))
        eachChild = eachChild.nextSibling
      clonedItem.appendChildren(children)

    remapIDCallback?(item.id, clonedItem.id, clonedItem)
    clonedItem

  # Public: Creates a copy of an {Item} from an external outline that can be
  # inserted into the current outline.
  #
  # - `item` {Item} to import.
  #
  # Returns {Item} copy.
  importItem: (item, deep=true, remapIDCallback) ->
    assert.ok(not item.isRoot, 'Can not import root item')
    assert.ok(item.outline isnt @, 'Item must not be owned by this outline')

    importedItem = @createItem(item.bodyAttributedString.clone(), item.id, remapIDCallback)

    if item.attributes
      importedItem.attributes = _.clone(item.attributes)
    if item.userData
      importedItem.userData = _.clone(item.userData)

    if deep and eachChild = item.firstChild
      children = []
      while eachChild
        children.push(@importItem(eachChild, deep))
        eachChild = eachChild.nextSibling
      importedItem.appendChildren(children)

    importedItem

  ###
  Section: Insert & Remove Items
  ###

  # Public: Insert the item before the given `referenceItem`. If the reference
  # item isn't defined insert at the end of the outline.
  #
  # Unlike {Item::insertChildBefore} this method uses {Item::indent} to
  # determine where in the outline structure to insert the item. Depending on
  # the indent value this item may become referenceItem's parent, previous
  # sibling, or unrelated.
  #
  # - `item` {Item} to insert.
  # - `referenceItem` Reference {Item} to insert before.
  insertItemBefore: (item, referenceItem) ->
    @insertItemsBefore([item], referenceItem)

  # Public: Insert the items before the given `referenceItem`. See
  # {Outline::insertItemBefore} for more implementation details. This method
  # works differently then {Item::insertChildrenBefore}.
  #
  # - `items` {Array} of {Item}s to insert.
  # - `referenceItem` Reference {Item} to insert before.
  insertItemsBefore: (items, referenceItem) ->
    unless items.length
      return

    @beginChanges()
    @undoManager.beginUndoGrouping()

    # 1. Group items into hiearhcies while saving roots.
    roots = Item.buildItemHiearchy(items)

    # 2. Make sure each root has indent of at least 1 so that they will always
    # insert as children of outline.root.
    for each in roots
      if each.indent < 1
        each.indent = 1

    # 3. Group roots by indentation level so they can all be inseted in a
    # single mutation instent of one by one.
    rootGroups = []
    currentDepth = undefined
    for each in roots
      if each.depth is currentDepth
        current.push(each)
      else
        current = [each]
        rootGroups.push(current)
        currentDepth = each.depth

    # 4. Insert root groups where appropriate in the outline.
    for eachGroup in rootGroups
      eachGroupDepth = eachGroup[0].depth
      # find insert point
      parent = referenceItem?.previousItemOrRoot or @root.lastDescendantOrSelf
      nextSibling = parent.firstChild
      parentDepth = parent.depth
      nextBranch = referenceItem
      while parentDepth >= eachGroupDepth
        nextSibling = parent.nextSibling
        parent = parent.parent
        parentDepth = parent.depth
      # restore indents and insert
      for each in eachGroup
        each.indent = eachGroupDepth - parent.depth
      parent.insertChildrenBefore(eachGroup, nextSibling, true)

    # 5. Reparent covered trailing branches to last inserted root.
    lastRoot = roots[roots.length - 1]
    ancestorStack = []
    each = lastRoot
    while each
      ancestorStack.push(each)
      each = each.lastChild

    trailingBranches = []
    while referenceItem and (referenceItem.depth > lastRoot.depth)
      trailingBranches.push(referenceItem)
      referenceItem = referenceItem.nextBranch

    Item.buildItemHiearchy(trailingBranches, ancestorStack)

    @undoManager.endUndoGrouping()
    @endChanges()

  # Public: Remove the item but leave it's child items in the outline.
  #
  # - `item` {Item} to remove.
  removeItem: (item) ->
    @removeItems([item])

  # Public: Remove the items but leave there child items in the outline.
  #
  # - `items` {Item}s to remove.
  removeItems: (items) ->
    # Group items into contiguous ranges so they are easier to reason about
    # when grouping the removes for efficiency.
    contiguousItemRanges = []
    previousItem = undefined
    for each in items
      if previousItem and previousItem is each.previousItem
        currentRange.push(each)
      else
        currentRange = [each]
        contiguousItemRanges.push(currentRange)
      previousItem = each

    @beginChanges()
    @undoManager.beginUndoGrouping()
    for each in contiguousItemRanges
      @_removeContiguousItems(each)
    @undoManager.endUndoGrouping()
    @endChanges()

  _removeContiguousItems: (items) ->
    # 1. Collect all items to remove together with their children. Only
    # some of these items are to be removed, the others will be reinserted.
    coveredItems = []
    coveredItemsSet = new Set()
    for each in items
      unless coveredItemsSet.has(eachChild)
        coveredItems.push(each)
        coveredItemsSet.add(each)
      for eachChild in each.children
        unless coveredItemsSet.has(eachChild)
          coveredItems.push(eachChild)
          coveredItemsSet.add(eachChild)

    # 2. Save item that reinserted items should be reinserted before.
    insertBefore = coveredItems[coveredItems.length - 1].nextBranch

    # 3. Figure out which items should be reinserted and save there depths.
    removeItemsSet = new Set()
    for each in items
      removeItemsSet.add(each)
    reinsertChildren = []
    for each, i in coveredItems
      unless removeItemsSet.has(each)
        reinsertChildren.push(each)

    # 4. Remove items to reinsert before removing items. This way undo will
    # work. since the parents are still in the tree.
    Item.removeItemsFromParents(reinsertChildren)

    # 5. Remove the items that are actually meant to be removed.
    Item.removeItemsFromParents(items)

    # 6. Reinsert!
    @insertItemsBefore(reinsertChildren, insertBefore)

  ###
  Section: Querying Items
  ###

  # Pubilc: Evaluate the item path starting with the root item and return all
  # matching items.
  #
  # - `itemPath` {String} itempath expression
  # - `contextItem` (optional)
  #
  # Returns an {Array} of matching {Item}s.
  evaluateItemPath: (itemPath, contextItem, options) ->
    options ?= {}
    options.root ?= @root
    contextItem ?= @root
    ItemPath.evaluate itemPath, contextItem, options

  ###
  Section: Grouping Changes
  ###

  # Public: Returns {Boolean} true if outline is updating.
  isChanging: -> @changingCount isnt 0
  isUpdating: -> @isChanging()

  # Public: Begin grouping changes. Must later call {::endChanges} to balance
  # this call.
  beginChanges: ->
    @changingCount++
    if @changingCount is 1
      @changesCallbacks = []
      @emitter.emit('did-begin-changes')

  breakUndoCoalescing: ->
    @coalescingMutation = null

  syncAttributeToBody: (item, name, value, oldValue) ->
    return unless @syncRules
    unless @syncingToAttributes
      @syncingToBody++
      for each in @syncRules
        each.syncAttributeToBody(item, name, value, oldValue)
      @syncingToBody--

  syncBodyToAttributes: (item, oldBody) ->
    return unless @syncRules
    unless @syncingToBody
      @syncingToAttributes++
      for each in @syncRules
        each.syncBodyToAttributes(item, oldBody)
      @syncingToAttributes--

  registerAttributeBodySyncRule: (syncRule) ->
    unless @syncRules
      @syncRules = []
    @syncRules.push(syncRule)
    new Disposable =>
      @syncRules.splice(@syncRules.indexOf(syncRule), 1)
      if @syncRules.length is 0
        @syncRules = null

  recordChange: (mutation) ->
    unless @undoManager.isUndoRegistrationEnabled()
      return

    if @undoManager.isUndoing or @undoManager.isUndoing
      @breakUndoCoalescing()

    if @coalescingMutation and @coalescingMutation.coalesce(mutation)
      metadata = @undoManager.getUndoGroupMetadata()
      undoSelection = metadata.undoSelection
      if undoSelection and @coalescingMutation.type is Mutation.BODY_CHANGED
        # Update the undo selection to match coalescingMutation
        undoSelection.anchorOffset = @coalescingMutation.insertedTextLocation
        undoSelection.startOffset = @coalescingMutation.insertedTextLocation
        undoSelection.focusOffset = @coalescingMutation.insertedTextLocation + @coalescingMutation.replacedText.length
        undoSelection.endOffset = @coalescingMutation.insertedTextLocation + @coalescingMutation.replacedText.length
    else
      @undoManager.registerUndoOperation mutation
      @coalescingMutation = mutation

  # Public: End grouping changes. Must call to balance a previous
  # {::beginChanges} call.
  #
  # - `callback` (optional) Callback is called when outline finishes updating.
  endChanges: (callback) ->
    @changesCallbacks.push(callback) if callback
    @changingCount--
    if @changingCount is 0
      @conflict = false if @conflict and not @isModified()
      @emitter.emit('did-end-changes')
      @scheduleModifiedEvents()

      changesCallbacks = @changesCallbacks
      @changesCallbacks = null
      for each in changesCallbacks
        each()

  ###
  Section: Undo
  ###

  # Essential: Undo the last change.
  undo: ->
    @undoManager.undo()

  # Essential: Redo the last change.
  redo: ->
    @undoManager.redo()

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
  Section: File Details
  ###

  # Public: Determine if the outline has changed since it was loaded.
  #
  # If the outline is unsaved, always returns `true` unless the outline is
  # empty.
  #
  # Returns a {Boolean}.
  isModified: ->
    return false unless @loaded
    if @file
      @changeCount isnt 0
    else
      not @isEmpty()

  # Public: Determine if the in-memory contents of the outline conflict with the
  # on-disk contents of its associated file.
  #
  # Returns a {Boolean}.
  isInConflict: -> @conflict

  getMimeType: ->
    unless @fileMimeType
      @fileMimeType = ItemSerializer.getMimeTypeForURI(@getPath()) or Constants.FTMLMimeType
    @fileMimeType

  setMimeType: (mimeType) ->
    unless @getMimeType() is mimeType
      @fileMimeType = mimeType

  # Public: Get the path of the associated file.
  #
  # Returns a {String}.
  getPath: ->
    @file?.getPath()

  # Public: Set the path for the outlines's associated file.
  #
  # - `filePath` A {String} representing the new file path
  setPath: (filePath) ->
    return if filePath is @getPath()

    if filePath
      @file = new File(filePath)
      @file.setEncoding('utf8')
      @subscribeToFile()
    else
      @file = null

    @emitter.emit 'did-change-path', @getPath()
    @setMimeType(null)

  getURI: (options) ->
    @getPath()

  # Public: Get an href to this outline.
  #
  # * `options` (optional) The {Object} with URL options (default: {}):
  #   * `hoistedItem` An {Item} to hoist when opening the outline
  #   * `query` A {String} item path to set when opening the outline.
  #   * `expanded` An {Array} of items to expand when opening the outline.
  #   * `selection` An {Object} with the selection to set when opening the outline.
  #     * `focusItem` The focus {Item}.
  #     * `focusOffset` The focus offset {Number}.
  #     * `anchorItem` The anchor {Item}.
  #     * `anchorOffset` The anchor offset {Number}.
  getFileURL: (options={}) ->
    urlOptions = {}

    hoistedItem = options.hoistedItem
    if hoistedItem and not hoistedItem.isRoot
      urlOptions.hash = hoistedItem.id

    if query = options.query
      urlOptions.query = query

    if expanded = options.expanded
      urlOptions.expanded = (each.id for each in expanded).join(',')

    if options.selection?.focusItem
      selection = options.selection
      focusItem = selection.focusItem
      focusOffset = selection.focusOffset ? undefined
      anchorItem = selection.anchorItem ? focusItem
      anchorOffset = selection.anchorOffset ? focusOffset
      urlOptions.selection = "#{focusItem?.id},#{focusOffset},#{anchorItem?.id},#{anchorOffset}"

    if @getPath()
      urls.getFileURLFromPathnameAndOptions(@getPath(), urlOptions)
    else
      # Hack... in case where outline has no path can't return file:// url
      # since they require and absolute path. So instead just return the
      # encoded options.
      urls.getHREFFromFileURLs('file:///', 'file:///', urlOptions)

  getBaseName: ->
    @file?.getBaseName() or 'Untitled'

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

  ###
  Section: File Content Operations
  ###

  # Public: Save the outline.
  save: (editor) ->
    @saveAs @getPath(), editor

  # Public: Save the outline at a specific path.
  #
  # - `filePath` The path to save at.
  saveAs: (filePath, editor) ->
    unless filePath then throw new Error("Can't save outline with no file path")

    @emitter.emit 'will-save', {path: filePath}
    @setPath(filePath)
    text = ItemSerializer.serializeItems(@root.children, editor, @getMimeType())
    @file.writeSync text
    @cachedDiskContents = text
    @conflict = false
    @updateChangeCount(Outline.ChangeCleared)
    @emitModifiedStatusChanged(false)
    @emitter.emit 'did-save', {path: filePath}

  # Public: Reload the outline's contents from disk.
  #
  # Sets the outline's content to the cached disk contents.
  reload: ->
    @emitter.emit 'will-reload'
    @beginChanges()
    @root.removeChildren(@root.children)
    if @cachedDiskContents
      items = ItemSerializer.deserializeItems(@cachedDiskContents, this, @getMimeType())
      @loadOptions = items.loadOptions
      @root.appendChildren(items)
    @endChanges()
    @updateChangeCount(Outline.ChangeCleared)
    @emitModifiedStatusChanged(false)
    @emitter.emit 'did-reload'

  updateCachedDiskContentsSync: (pathOverride) ->
    if pathOverride
      @cachedDiskContents = fs.readFileSync(pathOverride, 'utf8')
    else
      @cachedDiskContents = @file?.readSync() ? ""

  updateCachedDiskContents: (flushCache=false, callback) ->
    Q(@file?.read(flushCache) ? "").then (contents) =>
      @cachedDiskContents = contents
      callback?()

  updateChangeCount: (change) ->
    switch change
      when Outline.ChangeDone
        @changeCount++
      when Outline.ChangeUndone
        @changeCount--
      when Outline.ChangeCleared
        @changeCount = 0
      when Outline.ChangeRedone
        @changeCount++
    @nativeDocument?.updateChangeCount(change)

  ###
  Section: Debug
  ###

  # Extended: Returns debug string for this item.
  toString: ->
    this.root.branchToString()

  ###
  Section: Private Utility Methods
  ###

  nextOutlineUniqueItemID: (candidateID) ->
    loadingLIUsedIDs = @loadingLIUsedIDs
    while true
      id = candidateID or shortid()
      if loadingLIUsedIDs and not loadingLIUsedIDs[id]
        loadingLIUsedIDs[id] = true
        return id
      else if not @idsToItems.get(id)
        return id
      else
        candidateID = null

  loadSync: (pathOverride) ->
    @updateCachedDiskContentsSync(pathOverride)
    @finishLoading()

  load: ->
    @updateCachedDiskContents().then => @finishLoading()

  finishLoading: ->
    if @isAlive()
      @loaded = true
      @reload()
      @undoManager.removeAllActions()
    this

  destroy: ->
    unless @destroyed
      Outline.removeOutline this
      @cancelStoppedChangingTimeout()
      @undoSubscriptions?.dispose()
      @fileSubscriptions?.dispose()
      @nativeDocument = null
      @destroyed = true
      @emitter.emit 'did-destroy'

  isAlive: -> not @destroyed

  isDestroyed: -> @destroyed

  isRetained: -> @refcount > 0

  retain: ->
    @refcount++
    this

  release: (editorID) ->
    @refcount--
    for each in @getItems()
      each.setUserData editorID, undefined
    @destroy() unless @isRetained()
    this

  subscribeToFile: ->
    @fileSubscriptions?.dispose()
    @fileSubscriptions = new CompositeDisposable

    @fileSubscriptions.add @file.onDidChange =>
      @conflict = true if @isModified()
      previousContents = @cachedDiskContents

      # Synchronously update the disk contents because the {File} has already
      # cached them. If the contents updated asynchrounously multiple
      # `conlict` events could trigger for the same disk contents.
      @updateCachedDiskContentsSync()
      return if previousContents is @cachedDiskContents

      if @conflict
        @emitter.emit 'did-conflict'
      else
        @reload()

    @fileSubscriptions.add @file.onDidDelete =>
      modified = isModified()
      @wasModifiedBeforeRemove = modified
      @emitter.emit 'did-delete'
      if modified
        @updateCachedDiskContents()
      else
        @destroy()

    @fileSubscriptions.add @file.onDidRename =>
      @emitter.emit 'did-change-path', @getPath()

    @fileSubscriptions.add @file.onWillThrowWatchError (errorObject) =>
      @emitter.emit 'will-throw-watch-error', errorObject

  hasMultipleEditors: ->
    @refcount > 1

  cancelStoppedChangingTimeout: ->
    clearTimeout(@stoppedChangingTimeout) if @stoppedChangingTimeout

  scheduleModifiedEvents: ->
    @cancelStoppedChangingTimeout()
    stoppedChangingCallback = =>
      @stoppedChangingTimeout = null
      modifiedStatus = @isModified()
      @emitModifiedStatusChanged(modifiedStatus)
    @stoppedChangingTimeout = setTimeout(
      stoppedChangingCallback,
      @stoppedChangingDelay
    )

  emitModifiedStatusChanged: (modifiedStatus) ->
    return if modifiedStatus is @previousModifiedStatus
    @previousModifiedStatus = modifiedStatus
    @emitter.emit 'did-change-modified', modifiedStatus

Outline.ChangeDone = 0
Outline.ChangeUndone = 1
Outline.ChangeCleared = 2
Outline.ChangeReadOtherContents = 3
Outline.ChangeAutosaved = 4
Outline.ChangeRedone = 5
Outline.ChangeDiscardable = 256

module.exports = Outline