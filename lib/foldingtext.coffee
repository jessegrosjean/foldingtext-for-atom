# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

{Disposable, CompositeDisposable} = require 'atom'
OutlineEditor = null

atom.deserializers.add
  name: 'OutlineEditor'
  deserialize: (data={}) ->
    OutlineEditor ?= L('OutlineEditor')
    outline = L('Outline').getOutlineForPathSync(data.filePath)
    new OutlineEditor(outline, data)

module.exports =
  subscriptions: null
  createdFirstOutline: false
  statusBar: null
  statusBarDisposables: null

  config:
    disableAnimation:
      type: 'boolean'
      default: false

  provideFoldingTextService: ->
    L('FoldingTextService')

  activate: (state) ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace', 'outline-editor:new-outline': ->
      atom.workspace.open('outline-editor://new-outline')
    @subscriptions.add atom.commands.add 'atom-workspace', 'foldingtext:open-users-guide': ->
      L('shell').openExternal('http://jessegrosjean.gitbooks.io/foldingtext-for-atom-user-s-guide/content/')
    @subscriptions.add atom.commands.add 'atom-workspace', 'foldingtext:open-support-forum': ->
      L('shell').openExternal('http://support.foldingtext.com/c/foldingtext-for-atom')
    @subscriptions.add atom.commands.add 'atom-workspace', 'foldingtext:open-api-reference': ->
      L('shell').openExternal('http://www.foldingtext.com/foldingtext-for-atom/documentation/api-reference/')

    @subscriptions.add atom.workspace.addOpener (filePath) ->

      if filePath is 'outline-editor://new-outline'
        OutlineEditor ?= L('OutlineEditor')
        new OutlineEditor()
      else
        extension = L('path').extname(filePath).toLowerCase()
        if extension is '.ftml'
          L('Outline').getOutlineForPath(filePath).then (outline) ->
            OutlineEditor ?= L('OutlineEditor')
            new OutlineEditor(outline)

    #require './extensions/ui/popovers'
    #require './extensions/edit-link-popover'
    #require './extensions/text-formatting-popover'
    #require './extensions/priorities'
    #require './extensions/status'
    #require './extensions/tags'

  creatingOutlineEditor: ->
    unless @createdFirstOutline
      @createdFirstOutline = true
      @addStatusBarItemsIfReady()
      viewProviderSubscription = atom.views.addViewProvider L('OutlineEditor'), (model) ->
        model.outlineEditorElement
      # ? is hack so works with specs without having to do full package
      # activation
      @subscriptions?.add viewProviderSubscription

  consumeStatusBarService: (statusBar) ->
    @statusBar = statusBar
    @statusBarDisposables = new CompositeDisposable()
    @statusBarDisposables.add new Disposable =>
      @statusBar = null
    @addStatusBarItemsIfReady()
    @statusBarDisposables

  addStatusBarItemsIfReady: ->
    if @statusBar and @createdFirstOutline
      @statusBarDisposables.add L('LocationStatusBarItem').consumeStatusBarService(@statusBar)
      @statusBarDisposables.add L('SearchStatusBarItem').consumeStatusBarService(@statusBar)

  deactivate: ->
    @subscriptions.dispose()
    @createdFirstOutline = false

shortcutsToPaths =
  'Outline': './core/outline'
  'OutlineEditor': './editor/outline-editor'
  'FoldingTextService': './foldingtext-service'
  'LocationStatusBarItem': './extensions/location-status-bar-item'
  'SearchStatusBarItem': './extensions/search-status-bar-item'

L = (name) ->
  require(shortcutsToPaths[name] or name)
