# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

LocationStatusBarItem = require './extensions/location-status-bar-item'
SearchStatusBarItem = require './extensions/search-status-bar-item'
foldingTextService = require './foldingtext-service'
OutlineEditor = require './editor/outline-editor'
{CompositeDisposable} = require 'atom'
Outline = require './core/outline'
path = require 'path'

# Do this early because serlialization happens before package activation
atom.views.addViewProvider OutlineEditor, (model) ->
  model.outlineEditorElement

module.exports =
  subscriptions: null

  config:
    disableAnimation:
      type: 'boolean'
      default: false

  provideFoldingTextService: ->
    foldingTextService

  activate: (state) ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace', 'outline-editor:new-outline': ->
      atom.workspace.open('outline-editor://new-outline')

    @subscriptions.add atom.workspace.addOpener (filePath) ->
      if filePath is 'outline-editor://new-outline'
        new OutlineEditor
      else
        extension = path.extname(filePath).toLowerCase()
        if extension is '.ftml'
          Outline.getOutlineForPath(filePath).then (outline) ->
            new OutlineEditor(outline)

    require './extensions/ui/popovers'
    require './extensions/edit-link-popover'
    require './extensions/text-formatting-popover'
    require './extensions/priorities'
    require './extensions/status'
    require './extensions/tags'
    ###
    require '../packages/durations'
    require '../packages/mentions'
    require '../packages/tags'
    ###

    #@initializeGlobalOutlineEditorStyleSheet()
    #@observeTextEditorFontConfig()

  consumeStatusBarService: (statusBar) ->
    disposable = new CompositeDisposable()
    disposable.add LocationStatusBarItem.consumeStatusBarService(statusBar)
    disposable.add SearchStatusBarItem.consumeStatusBarService(statusBar)
    disposable

  deactivate: ->
    @subscriptions.dispose()