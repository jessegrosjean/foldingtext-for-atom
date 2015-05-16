# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

{Disposable, CompositeDisposable} = require 'atom'

# Public: This is the object vended by the `foldingtext-service` and the entry
# point to FoldingText's API.
#
# ## Example
#
# To get an instance of {FoldingTextService} you subscribe to FoldingText using
# Atom's [services
# API](https://atom.io/docs/latest/creating-a-package#interacting-with-other-
# packages-via-services). First subscibe to `foldingtext-service` in your
# package's `package.json` and then consume the service in your main module.
#
# ```cson
# "consumedServices": {
#   "foldingtext-service": {
#     "versions": {
#       "0": "consumeFoldingTextService"
#     }
#   }
# },
# ```
#
# ```coffeescript
# {Disposable, CompositeDisposable} = require 'atom'
#   ...
#   consumeFoldingTextService: (foldingTextService) ->
#     @foldingTextService = foldingTextService
#     new Disposable =>
#       @foldingTextService = null
# ```
class FoldingTextService

  ###
  Section: Classes
  ###

  # Public: {Item} Class
  Item: null # lazy
  Object.defineProperty @::, 'Item',
    get: -> require './core/item'

  # Public: {Outline} Class
  Outline: null # lazy
  Object.defineProperty @::, 'Outline',
    get: -> require './core/outline'

  # Public: {Mutation} Class
  Mutation: null # lazy
  Object.defineProperty @::, 'Mutation',
    get: -> require './core/mutation'

  # Public: {OutlineEditor} Class
  OutlineEditor: null # lazy
  Object.defineProperty @::, 'OutlineEditor',
    get: -> require './editor/outline-editor'

  ###
  Section: Workspace Outline Editors
  ###

  # Public: Get all outline editors in the workspace.
  #
  # Returns an {Array} of {OutlineEditor}s.
  getOutlineEditors: ->
    atom.workspace.getPaneItems().filter (item) ->
      item.isOutlineEditor

  # Public: Get the active item if it is an {OutlineEditor}.
  #
  # Returns an {OutlineEditor} or `undefined` if the current active item is
  # not an {OutlineEditor}.
  getActiveOutlineEditor: ->
    activeItem = atom.workspace.getActivePaneItem()
    activeItem if activeItem?.isOutlineEditor

  # Public: Get all outline editors for a given outine the workspace.
  #
  # - `outline` The {Outline} to search for.
  #
  # Returns an {Array} of {OutlineEditor}s.
  getOutlineEditorsForOutline: (outline) ->
    atom.workspace.getPaneItems().filter (item) ->
      item.isOutlineEditor and item.outline is outline

  ###
  Section: Event Subscription
  ###

  # Public: {EventRegistery} instance.
  eventRegistery: null # lazy
  Object.defineProperty @::, 'eventRegistery',
    get: -> require './editor/event-registery'

  # Public: Invoke the given callback when an outline editor is added to the
  # workspace.
  #
  # * `callback` {Function} to be called panes are added.
  #   * `event` {Object} with the following keys:
  #     * `outlineEditor` {OutlineEditor} that was added.
  #     * `pane` {Pane} containing the added outline editor.
  #     * `index` {Number} indicating the index of the added outline editor
  #       in its pane.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddOutlineEditor: (callback) ->
    atom.workspace.onDidAddPaneItem ({item, pane, index}) ->
      if item.isOutlineEditor
        callback({outlineEditor: item, pane, index})

  # Public: Invoke the given callback with all current and future outline
  # editors in the workspace.
  #
  # * `callback` {Function} to be called with current and future outline
  #    editors.
  #   * `editor` An {OutlineEditor} that is present in {::getOutlineEditors}
  #      at the time of subscription or that is added at some later time.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeOutlineEditors: (callback) ->
    callback(outlineEditor) for outlineEditor in @getOutlineEditors()
    @onDidAddOutlineEditor ({outlineEditor}) -> callback(outlineEditor)

  # Public: Invoke the given callback when the active {OutlineEditor} changes.
  #
  # * `callback` {Function} to be called when the active {OutlineEditor} changes.
  #   * `outlineEditor` The active OutlineEditor.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeActiveOutlineEditor: (callback) ->
    prev = null
    atom.workspace.onDidChangeActivePaneItem (item) ->
      unless item?.isOutlineEditor
        item = null
      unless prev is item
        callback item
        prev = item

  # Public: Invoke the given callback with the current {OutlineEditor} and
  # with all future active outline editors in the workspace.
  #
  # * `callback` {Function} to be called when the {OutlineEditor} changes.
  #   * `outlineEditor` The current active {OultineEditor}.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeActiveOutlineEditor: (callback) ->
    prev = {}
    atom.workspace.observeActivePaneItem (item) ->
      unless item?.isOutlineEditor
        item = null
      unless prev is item
        callback item
        prev = item

  # Public: Invoke the given callback when the active {OutlineEditor}
  # {Selection} changes.
  #
  # * `callback` {Function} to be called when the active {OutlineEditor} {Selection} changes.
  #   * `selection` The active {OutlineEditor} {Selection}.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeActiveOutlineEditorSelection: (callback) ->
    selectionSubscription = null
    activeEditorSubscription = @observeActiveOutlineEditor (outlineEditor) ->
      selectionSubscription?.dispose()
      selectionSubscription = outlineEditor?.onDidChangeSelection callback
      callback outlineEditor?.selection or null
    new Disposable ->
      selectionSubscription?.dispose()
      activeEditorSubscription.dispose()

  # Public: Invoke the given callback with the active {OutlineEditor} {Selection} and
  # with all future active outline editor selections in the workspace.
  #
  # * `callback` {Function} to be called when the {OutlineEditor} {Selection} changes.
  #   * `selection` The current active {OultineEditor} {Selection}.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeActiveOutlineEditorSelection: (callback) ->
    callback @getActiveOutlineEditor()?.selection or null
    @onDidChangeActiveOutlineEditorSelection callback

module.exports = new FoldingTextService
