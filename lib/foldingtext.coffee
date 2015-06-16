# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

{Disposable, CompositeDisposable} = require 'atom'
foldingTextService = require './foldingtext-service'
ItemSerializer = null
OutlineEditor = null
Outline = null
path = null
url = null
Q = null

atom.deserializers.add
  name: 'OutlineEditorDeserializer'
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
        require './extensions/edit-link-popover'
        require './extensions/priorities'
        require './extensions/status'
        require './extensions/tags'
        @addStatusBarItemsIfReady()
        @workspaceDisplayedEditor = true

    @subscriptions.add atom.workspace.addOpener (uri, options) ->
      if uri is 'outline-editor://new-outline'
        Outline ?= require('./core/outline')
        OutlineEditor ?= require('./editor/outline-editor')
        Outline.getOutlineForPath(null, true).then (outline) ->
          new OutlineEditor(outline)

    @subscriptions.add atom.workspace.addOpener (uri, options) ->
      ItemSerializer ?= require('./core/item-serializer')
      if ItemSerializer.getMimeTypeForURI(uri)
        Outline ?= require('./core/outline')
        OutlineEditor ?= require('./editor/outline-editor')
        Outline.getOutlineForPath(uri).then (outline) ->
          if outline
            new OutlineEditor(outline, options)

    @subscriptions.add atom.packages.onDidActivatePackage (pack) ->
      if pack.name is 'foldingtext-for-atom'
        if process.platform is 'darwin'
          path ?= require('path')
          exec = require('child_process').exec
          packagePath = atom.packages.getActivePackage('foldingtext-for-atom').path
          FoldingTextHelperPath = path.join(packagePath, 'native', 'darwin', 'FoldingTextHelper.app')
          lsregister = '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
          exec "#{lsregister} #{FoldingTextHelperPath}"

    @subscriptions.add @monkeyPatchWorkspaceOpen()

  monkeyPatchWorkspaceOpen: ->
    # Patched for two purposes. First strip off URL params and move them to
    # options. Second call updateOptionsAfterOpenOrReopen so item gets options
    # anytime it is opened, not just the first time.
    workspaceOriginalOpen = atom.workspace.open
    workspaceMonkeyOpen = (args...) ->
      uri = args[0]
      options = args[1]

      try
        if uri
          url ?= require('url')
          urlObject = url.parse(uri, true)
          path ?= require('path')
          pathObject = {}
          options ?= {}

          if urlObject.protocol is 'file:'
            decodedPath = decodeURI(urlObject.path)
            # Maybe better way to do this, but here I'm detecting windows drive
            # letter case and when found I strip off leading /. Odd and ugly.
            if decodedPath.match(/^\/[a-zA-Z]:/)
              decodedPath = decodedPath.substr(1)
            pathObject = path.parse(decodedPath)
          else
            pathObject = path.parse(uri)

          ItemSerializer ?= require('./core/item-serializer')
          unless ItemSerializer.getMimeTypeForURI(pathObject.base)
            urlObject = url.parse(pathObject.base, true)
            if ItemSerializer.getMimeTypeForURI(urlObject.pathname)
              options.hash ?= (urlObject.hash or '#').substr(1)
              options[key] ?= value for key, value of urlObject.query
              pathObject.base = urlObject.pathname
              uri = path.format(pathObject)
              args[0] = uri
              args[1] = options
      catch error
        console.log error

      openPromise = workspaceOriginalOpen.apply(atom.workspace, args)
      openPromise?.then? (item) ->
        item.updateOptionsAfterOpenOrReopen?(options)
      openPromise
    atom.workspace.open = workspaceMonkeyOpen
    new Disposable ->
      if atom.workspace.open is workspaceMonkeyOpen
        atom.workspace.open = workspaceOriginalOpen

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
