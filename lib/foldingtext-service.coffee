# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

{Disposable, CompositeDisposable} = require 'atom'
eventRegistery = require './editor/event-registery'
OutlineEditor = require './editor/outline-editor'
Mutation = require './core/mutation'
Outline = require './core/outline'
Item = require './core/item'

# Public: This is the object vended by the `ft-foldingtext-service` and the
# entry point to FoldingText's API.
#
# ## Examples
#
# To get an instance of {FoldingTextService} you subscribe to `foldingtext-
# service` using Atom's #[services
# API](https://atom.io/docs/latest/creating-a-package#interacting-with-other-
# packages-via-services).
#
# First subscibe to `foldingtext- service` in your package's `package.json`
# and then consume the service in your main module.
#
# ```cson
# "consumedServices": {
#   "foldingtext-service": {
#     "versions": {
#       "1": "consumeFoldingTextService"
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
  Item: Item

  # Public: {Outline} Class
  Outline: Outline

  # Public: {Mutation} Class
  Mutation: Mutation

  # Public: {OutlineEditor} Class
  OutlineEditor: OutlineEditor

  ###
  Section: Workspace Outline Editors
  ###

  # Public: Get all outline editors in the workspace.
  #
  # Returns an {Array} of {OutlineEditor}s.
  getOutlineEditors: ->
    atom.workspace.getPaneItems().filter (item) -> item instanceof OutlineEditor

  # Public: Get the active item if it is an {OutlineEditor}.
  #
  # Returns an {OutlineEditor} or `undefined` if the current active item is
  # not an {OutlineEditor}.
  getActiveOutlineEditor: ->
    activeItem = atom.workspace.getActivePaneItem()
    activeItem if activeItem instanceof OutlineEditor

  # Public: Get all outline editors for a given outine the workspace.
  #
  # - `outline` The {Outline} to search for.
  #
  # Returns an {Array} of {OutlineEditor}s.
  getOutlineEditorsForOutline: (outline) ->
    atom.workspace.getPaneItems().filter (item) ->
      item instanceof OutlineEditor and item.outline is outline

  ###
  Section: Event Subscription
  ###

  # Public: {EventRegistery} instance.
  eventRegistery: eventRegistery

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
      if item instanceof OutlineEditor
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
      unless item instanceof OutlineEditor
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
      unless item instanceof OutlineEditor
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