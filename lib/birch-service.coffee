# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

{Disposable, CompositeDisposable} = require 'atom'

# Public: This is the object vended by the `birch-service` and the entry
# point to Birch's API.
#
# ## Example
#
# To get an instance of {BirchService} you subscribe to Birch using
# Atom's [services
# API](https://atom.io/docs/latest/creating-a-package#interacting-with-other-
# packages-via-services). First subscibe to `birch-service` in your
# package's `package.json` and then consume the service in your main module.
#
# ```cson
# "consumedServices": {
#   "birch-service": {
#     "versions": {
#       "0": "consumeBirchService"
#     }
#   }
# },
# ```
#
# ```coffeescript
# {Disposable, CompositeDisposable} = require 'atom'
#   ...
#   consumeBirchService: (birchService) ->
#     @birchService = birchService
#     new Disposable =>
#       @birchService = null
# ```
class BirchService

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

  # Public: {Editor} Class
  Editor: null # lazy
  Object.defineProperty @::, 'Editor',
    get: -> require './editor/outline-editor'

  ###
  Section: Workspace Outline Editors
  ###

  # Public: Get all outline editors in the workspace.
  #
  # Returns an {Array} of {Editor}s.
  getEditors: ->
    atom.workspace.getPaneItems().filter (item) ->
      item.isEditor

  # Public: Get the active item if it is an {Editor}.
  #
  # Returns an {Editor} or `undefined` if the current active item is
  # not an {Editor}.
  getActiveEditor: ->
    activeItem = atom.workspace.getActivePaneItem()
    activeItem if activeItem?.isEditor

  # Public: Get all outline editors for a given outine the workspace.
  #
  # - `outline` The {Outline} to search for.
  #
  # Returns an {Array} of {Editor}s.
  getEditorsForOutline: (outline) ->
    atom.workspace.getPaneItems().filter (item) ->
      item.isEditor and item.outline is outline

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
  #     * `outlineEditor` {Editor} that was added.
  #     * `pane` {Pane} containing the added outline editor.
  #     * `index` {Number} indicating the index of the added outline editor
  #       in its pane.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidAddEditor: (callback) ->
    atom.workspace.onDidAddPaneItem ({item, pane, index}) ->
      if item.isEditor
        callback({outlineEditor: item, pane, index})

  # Public: Invoke the given callback with all current and future outline
  # editors in the workspace.
  #
  # * `callback` {Function} to be called with current and future outline
  #    editors.
  #   * `editor` An {Editor} that is present in {::getEditors}
  #      at the time of subscription or that is added at some later time.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeEditors: (callback) ->
    callback(outlineEditor) for outlineEditor in @getEditors()
    @onDidAddEditor ({outlineEditor}) -> callback(outlineEditor)

  # Public: Invoke the given callback when the active {Editor} changes.
  #
  # * `callback` {Function} to be called when the active {Editor} changes.
  #   * `outlineEditor` The active Editor.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeActiveEditor: (callback) ->
    prev = null
    atom.workspace.onDidChangeActivePaneItem (item) ->
      unless item?.isEditor
        item = null
      unless prev is item
        callback item
        prev = item

  # Public: Invoke the given callback with the current {Editor} and
  # with all future active outline editors in the workspace.
  #
  # * `callback` {Function} to be called when the {Editor} changes.
  #   * `outlineEditor` The current active {OultineEditor}.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeActiveEditor: (callback) ->
    prev = {}
    atom.workspace.observeActivePaneItem (item) ->
      unless item?.isEditor
        item = null
      unless prev is item
        callback item
        prev = item

  # Public: Invoke the given callback when the active {Editor}
  # {Selection} changes.
  #
  # * `callback` {Function} to be called when the active {Editor} {Selection} changes.
  #   * `selection` The active {Editor} {Selection}.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeActiveEditorSelection: (callback) ->
    selectionSubscription = null
    activeEditorSubscription = @observeActiveEditor (outlineEditor) ->
      selectionSubscription?.dispose()
      selectionSubscription = outlineEditor?.onDidChangeSelection callback
      callback outlineEditor?.selection or null
    new Disposable ->
      selectionSubscription?.dispose()
      activeEditorSubscription.dispose()

  # Public: Invoke the given callback with the active {Editor} {Selection} and
  # with all future active outline editor selections in the workspace.
  #
  # * `callback` {Function} to be called when the {Editor} {Selection} changes.
  #   * `selection` The current active {OultineEditor} {Selection}.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  observeActiveEditorSelection: (callback) ->
    callback @getActiveEditor()?.selection or null
    @onDidChangeActiveEditorSelection callback

module.exports = new BirchService
