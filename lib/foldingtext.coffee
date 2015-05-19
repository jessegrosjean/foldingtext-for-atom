# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

{Disposable, CompositeDisposable} = require 'atom'
foldingTextService = require './foldingtext-service'
OutlineEditor = null
Outline = null

atom.deserializers.add
  name: 'OutlineEditor'
  deserialize: (data={}) ->
    OutlineEditor ?= require('./editor/outline-editor')
    outline = require('./core/outline').getOutlineForPathSync(data.filePath)
    new OutlineEditor(outline, data)

module.exports =
  subscriptions: null
  statusBar: null
  statusBarDisposables: null
  statusBarAddedItems: false
  workspaceDisplayedEditor: false

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
    @subscriptions.add atom.commands.add 'atom-workspace', 'foldingtext:open-users-guide': ->
      require('shell').openExternal('http://jessegrosjean.gitbooks.io/foldingtext-for-atom-user-s-guide/content/')
    @subscriptions.add atom.commands.add 'atom-workspace', 'foldingtext:open-support-forum': ->
      require('shell').openExternal('http://support.foldingtext.com/c/foldingtext-for-atom')
    @subscriptions.add atom.commands.add 'atom-workspace', 'foldingtext:open-api-reference': ->
      require('shell').openExternal('http://www.foldingtext.com/foldingtext-for-atom/documentation/api-reference/')

    @subscriptions.add foldingTextService.observeOutlineEditors =>
      unless @workspaceDisplayedEditor
        require './extensions/ui/popovers'
        require './extensions/text-formatting-popover'
        require './extensions/edit-link-popover'
        require './extensions/priorities'
        require './extensions/status'
        require './extensions/tags'
        @addStatusBarItemsIfReady()
        @workspaceDisplayedEditor = true

    @subscriptions.add atom.workspace.addOpener (filePath) ->
      if filePath is 'outline-editor://new-outline'
        Outline ?= require('./core/outline')
        OutlineEditor ?= require('./editor/outline-editor')
        Outline.getOutlineForPath(null, true).then (outline) ->
          new OutlineEditor(outline)
      else
        if mimeType = require('./core/item-serializer').getMimeTypeForURI(filePath)
          Outline ?= require('./core/outline')
          OutlineEditor ?= require('./editor/outline-editor')
          Outline.getOutlineForPath(filePath).then (outline) ->
            if outline
              new OutlineEditor(outline)
            else
              null

  consumeStatusBarService: (statusBar) ->
    @statusBar = statusBar
    @statusBarDisposables = new CompositeDisposable()
    @statusBarDisposables.add new Disposable =>
      @statusBar = null
      @statusBarDisposables = null
      @statusBarAddedItems = false
    @addStatusBarItemsIfReady()
    @subscriptions.add @statusBarDisposables
    @statusBarDisposables

  addStatusBarItemsIfReady: ->
    if @statusBar and not @statusBarAddedItems
      LocationStatusBarItem = require './extensions/location-status-bar-item'
      SearchStatusBarItem = require './extensions/search-status-bar-item'
      @statusBarDisposables.add LocationStatusBarItem.consumeStatusBarService(@statusBar)
      @statusBarDisposables.add SearchStatusBarItem.consumeStatusBarService(@statusBar)
      @statusBarAddedItems = true

  deactivate: ->
    @subscriptions.dispose()
    @statusBarAddedItems = false
    @workspaceDisplayedEditor = false
