# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

{Disposable, CompositeDisposable} = require 'atom'
birchService = require './birch-service'
ItemSerializer = null
Outline = null
Editor = null
path = null
url = null
Q = null
_ = null

atom.deserializers.add
  name: 'EditorDeserializer'
  deserialize: (data={}) ->
    Editor ?= require('./editor/outline-editor')
    outline = require('./core/outline').getOutlineForPathSync(data.filePath)
    new Editor(outline, data)

module.exports =
  subscriptions: null
  statusBar: null
  statusBarDisposables: null
  statusBarAddedItems: false
  workspaceDisplayedEditor: false

  config:
    disableAnimation:
      type: 'boolean'
      default: true

  provideBirchService: ->
    birchService

  activate: (state) ->
    @subscriptions = new CompositeDisposable

    @subscriptions.add atom.commands.add 'atom-workspace', 'outline-editor:new-outline': ->
      atom.workspace.open('outline-editor://new-outline')
    @subscriptions.add atom.commands.add 'atom-workspace', 'birch:open-users-guide': ->
      require('shell').openExternal('http://jessegrosjean.gitbooks.io/birch-for-atom-user-s-guide/content/')
    @subscriptions.add atom.commands.add 'atom-workspace', 'birch:open-support-forum': ->
      require('shell').openExternal('http://support.birch.com/c/birch-for-atom')
    @subscriptions.add atom.commands.add 'atom-workspace', 'birch:open-api-reference': ->
      require('shell').openExternal('http://www.birch.com/birch-for-atom/documentation/api-reference/')

    @subscriptions.add birchService.observeEditors =>
      unless @workspaceDisplayedEditor
        require './extensions/ui/popovers'
        #require './extensions/edit-link-popover'
        require './extensions/priorities'
        require './extensions/status'
        require './extensions/tags'
        @addStatusBarItemsIfReady()
        @workspaceDisplayedEditor = true

    @subscriptions.add atom.workspace.addOpener (uri, options) ->
      if uri is 'outline-editor://new-outline'
        Outline ?= require('./core/outline')
        Editor ?= require('./editor/outline-editor')
        Outline.getOutlineForPath(null, true).then (outline) ->
          new Editor(outline)

    @subscriptions.add atom.workspace.addOpener (uri, options) ->
      ItemSerializer ?= require('./core/item-serializer')
      if ItemSerializer.getMimeTypeForURI(uri)
        Outline ?= require('./core/outline')
        Editor ?= require('./editor/outline-editor')
        Outline.getOutlineForPath(uri).then (outline) ->
          if outline
            new Editor(outline, options)

    @subscriptions.add atom.packages.onDidActivatePackage (pack) ->
      if pack.name is 'birch-for-atom'
        if process.platform is 'darwin'
          path ?= require('path')
          exec = require('child_process').exec
          packagePath = atom.packages.getActivePackage('birch-for-atom').path
          BirchHelperPath = path.join(packagePath, 'native', 'darwin', 'BirchHelper.app')
          lsregister = '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
          exec "#{lsregister} #{BirchHelperPath}"

    require './text/init'

    @subscriptions.add @monkeyPatchWorkspaceOpen()

  monkeyPatchWorkspaceOpen: ->
    # Patched for two purposes. First strip off URL params and move them to
    # options. Second call updateOptionsAfterOpenOrReopen so item gets options
    # anytime it is opened, not just the first time. This patch only effects
    # file:// urls where there is an outline mime type defined for the url
    # pathname.
    workspaceOriginalOpen = atom.workspace.open
    workspaceMonkeyOpen = (args...) ->
      uri = args[0]
      options = args[1]

      try
        if uri
          url ?= require('url')
          urlObject = url.parse(uri, true)
          # Only mess with file URLs
          if urlObject.protocol is 'file:'
            ItemSerializer ?= require('./core/item-serializer')
            # Only mess with file URLs that have outline mime type
            if ItemSerializer.getMimeTypeForURI(urlObject.pathname)
              result = require('./core/url-util').getPathnameAndOptionsFromFileURL(urlObject)
              _ ?= require 'underscore-plus'
              _.extend(result.options, options)
              args[0] = result.pathname
              args[1] = options = result.options
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
