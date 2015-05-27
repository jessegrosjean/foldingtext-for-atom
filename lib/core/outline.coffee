# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

{File, Emitter, CompositeDisposable} = require 'atom'
ItemSerializer = require './item-serializer'
UndoManager = require './undo-manager'
Constants = require './constants'
ItemPath = require './item-path'
Mutation = require './mutation'
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
# described in [FoldingText Markup Language](http://jessegrosjean.gitbooks.io
# /foldingtext-for-atom-user-s-guide/content/appendix_b_file_format.html).
#
# ## Examples
#
# Group multiple changes:
#
# ```coffeescript
# outline.beginUpdates()
# root = outline.root
# root.appendChild outline.createItem()
# root.appendChild outline.createItem()
# root.firstChild.bodyText = 'first'
# root.lastChild.bodyText = 'last'
# outline.endUpdates()
# ```
#
# Watch for outline changes:
#
# ```coffeescript
# disposable = outline.onDidChange (mutations) ->
#   for mutation in mutations
#     switch mutation.type
#       when Mutation.ATTRIBUTE_CHANGED
#         console.log mutation.attributeName
#       when Mutation.BODT_TEXT_CHANGED
#         console.log mutation.target.bodyText
#       when Mutation.CHILDREN_CHANGED
#         console.log mutation.addedItems
#         console.log mutation.removedItems
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
  refcount: 0
  changeCount: 0
  undoSubscriptions: null
  updateCount: 0
  updateMutations: null
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
    @outlineStore = @createOutlineStore()

    rootElement = @outlineStore.getElementById Constants.RootID
    @loadingLIUsedIDs = {}
    @root = @createItem null, rootElement
    @loadingLIUsedIDs = null

    @undoManager = undoManager = new UndoManager
    @emitter = new Emitter

    @loaded = false
    @loadOptions = {}

    @undoSubscriptions = new CompositeDisposable
    @undoSubscriptions.add undoManager.onDidCloseUndoGroup =>
      unless undoManager.isUndoing or undoManager.isRedoing
        @changeCount++
        @scheduleModifiedEvents()
    @undoSubscriptions.add undoManager.onWillUndo =>
      @breakUndoCoalescing()
    @undoSubscriptions.add undoManager.onDidUndo =>
      @changeCount--
      @breakUndoCoalescing()
      @scheduleModifiedEvents()
    @undoSubscriptions.add undoManager.onWillRedo =>
      @breakUndoCoalescing()
    @undoSubscriptions.add undoManager.onDidRedo =>
      @changeCount++
      @breakUndoCoalescing()
      @scheduleModifiedEvents()

    @setPath(options.filePath) if options?.filePath
    @load() if options?.load

  createOutlineStore: (outlineStore) ->
    outlineStore = document.implementation.createHTMLDocument()
    rootUL = outlineStore.createElement('ul')
    rootUL.id = Constants.RootID
    outlineStore.documentElement.lastChild.appendChild(rootUL)
    outlineStore

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

  # Public: Invoke the given callback synchronously _before_ the outline
  # changes.
  #
  # Because observers are invoked synchronously, it's important not to perform
  # any expensive operations via this method.
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
  #   - `mutations` {Array} of {Mutation}s describing the changes.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChange: (callback) ->
    @emitter.on 'did-change', callback

  onDidStopChanging: (callback) ->
    @emitter.on 'did-stop-changing', callback

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

  # Public: Returns an {Array} of all {Item}s in the outline (except the
  # root) in outline order.
  getItems: ->
    @root.descendants

  isEmpty: ->
    firstChild = @root.firstChild
    not firstChild or
        (not firstChild.nextItem and
        firstChild.bodyText.length is 0)

  # Public: Returns {Item} for given id.
  #
  # - `id` {String} id.
  getItemForID: (id) ->
    @outlineStore.getElementById(id)?._item

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

  ###
  Section: Creating Items
  ###

  # Public: Create a new item. The new item is owned by this outline, but is
  # not yet inserted into it so it won't be visible until you insert it.
  #
  # - `text` (optional) {String} or {AttributedString}.
  createItem: (text, LIOrID, remapIDCallback) ->
    if LIOrID and _.isString(LIOrID)
      LI = @createStoreLI()
      LI.id = LIOrID
      LIOrID = LI
    new Item(@, text, LIOrID or @createStoreLI(), remapIDCallback)

  cloneItem: (item) ->
    assert.ok(not item.isRoot, 'Can not clone root')
    assert.ok(item.outline is @, 'Item must be owned by this outline')
    @createItem(null, item._liOrRootUL.cloneNode(true))

  # Public: Creates a copy of an {Item} from an external outline that can be
  # inserted into the current outline.
  #
  # - `item` {Item} to import.
  #
  # Returns {Item} copy.
  importItem: (item) ->
    assert.ok(not item.isRoot, 'Can not import root item')
    assert.ok(item.outline isnt @, 'Item must not be owned by this outline')
    @createItem(null, @outlineStore.importNode(item._liOrRootUL, true))

  removeItemsFromParents: (items) ->
    siblings = []
    prev = null

    for each in items
      if not prev or prev.nextSibling is each
        siblings.push(each)
      else
        @removeSiblingsFromParent(siblings)
        siblings = [each]
      prev = each

    if siblings.length
      @removeSiblingsFromParent(siblings);

  removeSiblingsFromParent: (siblings) ->
    return unless siblings.length

    firstSibling = siblings[0]
    outline = firstSibling.outline
    parent = firstSibling.parent

    return unless parent

    nextSibling = siblings[siblings.length - 1].nextSibling
    isInOutline = firstSibling.isInOutline
    undoManager = outline.undoManager

    if isInOutline
      if undoManager.isUndoRegistrationEnabled()
        undoManager.registerUndoOperation ->
          parent.insertChildrenBefore(siblings, nextSibling)

      undoManager.disableUndoRegistration()
      outline.beginUpdates()

    for each in siblings
      parent.removeChild each

    if isInOutline
      undoManager.enableUndoRegistration()
      outline.endUpdates()

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

  # Public: XPath query internal HTML structure.
  #
  # - `xpathExpression` {String} xpath expression
  # - `contextItem` (optional)
  # - `namespaceResolver` (optional)
  # - `resultType` (optional)
  # - `result` (optional)
  #
  # This query evaluates on the underlying HTMLDocument. Please refer to the
  # standard [document.evaluate](https://developer.mozilla.org/en-
  # US/docs/Web/API/document.evaluate) documentation for details.
  #
  # Returns an [XPathResult](https://developer.mozilla.org/en-
  # US/docs/XPathResult) based on an [XPath](https://developer.mozilla.org/en-
  # US/docs/Web/XPath) expression and other given parameters.
  evaluateXPath: (xpathExpression, contextItem, namespaceResolver, resultType, result) ->
    contextItem ?= @root
    @outlineStore.evaluate(
      xpathExpression,
      contextItem._liOrRootUL,
      namespaceResolver,
      resultType,
      result
    )

  # Public: XPath query internal HTML structure for matching {Items}.
  #
  # Items are considered to match if they, or a node contained in their body
  # text, matches the XPath.
  #
  # - `xpathExpression` {String} xpath expression
  # - `contextItem` (optional) {String}
  # - `namespaceResolver` (optional) {String}
  #
  # Returns an {Array} of all {Item} matching the
  # [XPath](https://developer.mozilla.org/en-US/docs/Web/XPath) expression.
  getItemsForXPath: (xpathExpression, contextItem, namespaceResolver, exceptionCallback) ->
    try
      xpathResult = @evaluateXPath(
        xpathExpression,
        contextItem,
        null,
        XPathResult.ORDERED_NODE_ITERATOR_TYPE
      )
      each = xpathResult.iterateNext()
      lastItem = undefined
      items = []

      while each
        while each and not each._item
          each = each.parentNode
        if each
          eachItem = each._item
          if eachItem isnt lastItem
            items.push(eachItem)
            lastItem = eachItem
        each = xpathResult.iterateNext()

      return items
    catch error
      exceptionCallback?(error)

    []

  ###
  Section: Grouping Changes
  ###

  # Public: Returns {Boolean} true if outline is updating.
  isUpdating: -> @updateCount isnt 0

  # Public: Begin grouping changes. Must later call {::endUpdates} to balance
  # this call.
  beginUpdates: ->
    if ++@updateCount is 1
      @updateMutations = []

  breakUndoCoalescing: ->
    @coalescingMutation = null

  recoredUpdateMutation: (mutation) ->
    @updateMutations.push mutation.copy()

    if @undoManager.isUndoing or @undoManager.isUndoing
      @breakUndoCoalescing()

    if @coalescingMutation and @coalescingMutation.coalesce(mutation)
      metadata = @undoManager.getUndoGroupMetadata()
      undoSelection = metadata.undoSelection
      if undoSelection and @coalescingMutation.type is Mutation.BODT_TEXT_CHANGED
        # Update the undo selection to match coalescingMutation
        undoSelection.anchorOffset = @coalescingMutation.insertedTextLocation
        undoSelection.startOffset = @coalescingMutation.insertedTextLocation
        undoSelection.focusOffset = @coalescingMutation.insertedTextLocation + @coalescingMutation.replacedText.length
        undoSelection.endOffset = @coalescingMutation.insertedTextLocation + @coalescingMutation.replacedText.length
    else
      @undoManager.registerUndoOperation mutation
      @coalescingMutation = mutation

  # Public: End grouping changes. Must call to balance a previous
  # {::beginUpdates} call.
  endUpdates: ->
    if --@updateCount is 0
      updateMutations = @updateMutations
      @updateMutations = null
      if updateMutations.length > 0
        @conflict = false if @conflict and not @isModified()
        @emitter.emit('did-change', updateMutations)
        @scheduleModifiedEvents()

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
      #if @file.existsSync()
      #  @getText() isnt @cachedDiskContents
      #else
      #  @wasModifiedBeforeRemove ? not @isEmpty()
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

  getUri: ->
    @getPath()

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
    @changeCount = 0
    @emitModifiedStatusChanged(false)
    @emitter.emit 'did-save', {path: filePath}

  # Public: Reload the outline's contents from disk.
  #
  # Sets the outline's content to the cached disk contents.
  reload: ->
    @emitter.emit 'will-reload'
    @beginUpdates()
    @root.removeChildren(@root.children)
    if @cachedDiskContents
      items = ItemSerializer.deserializeItems(@cachedDiskContents, this, @getMimeType())
      @loadOptions = items.loadOptions
      for each in items
        @root.appendChild(each)
    @endUpdates()
    @changeCount = 0
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

  ###
  Section: Private Utility Methods
  ###

  createStoreLI: ->
    outlineStore = @outlineStore
    li = outlineStore.createElement('LI')
    li.appendChild(outlineStore.createElement('P'))
    li

  nextOutlineUniqueItemID: (candidateID) ->
    loadingLIUsedIDs = @loadingLIUsedIDs
    while true
      id = candidateID or shortid()
      if loadingLIUsedIDs and not loadingLIUsedIDs[id]
        loadingLIUsedIDs[id] = true
        return id
      else if not @outlineStore.getElementById(id)
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
      @emitter.emit 'did-stop-changing'
      @emitModifiedStatusChanged(modifiedStatus)
    @stoppedChangingTimeout = setTimeout(
      stoppedChangingCallback,
      @stoppedChangingDelay
    )

  emitModifiedStatusChanged: (modifiedStatus) ->
    return if modifiedStatus is @previousModifiedStatus
    @previousModifiedStatus = modifiedStatus
    @emitter.emit 'did-change-modified', modifiedStatus

module.exports = Outline
