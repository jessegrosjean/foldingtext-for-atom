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
        require './extensions/text-formatting-popover'
        require './extensions/edit-link-popover'
        require './extensions/priorities'
        require './extensions/status'
        require './extensions/tags'
        @addStatusBarItemsIfReady()
        @workspaceDisplayedEditor = true

    @subscriptions.add atom.workspace.addOpener (filePath, options) ->
      if filePath is 'outline-editor://new-outline'
        Outline ?= require('./core/outline')
        OutlineEditor ?= require('./editor/outline-editor')
        Outline.getOutlineForPath(null, true).then (outline) ->
          new OutlineEditor(outline)

    @subscriptions.add atom.workspace.addOpener (filePath, options) ->
      ItemSerializer ?= require('./core/item-serializer')
      url ?= require('url')
      urlObject = url.parse(filePath, true)
      path ?= require('path')
      pathObject = {}

      # 1. Get path object
      if urlObject.protocol is 'file:'
        decodedPath = decodeURI(urlObject.path)
        # Maybe better way to do this, but here I'm detecting windows drive
        # letter case and when found I strip off leading /. Odd and ugly.
        if decodedPath.match(/^\/[a-zA-Z]:/)
          decodedPath = decodedPath.substr(1)
        pathObject = path.parse(decodedPath)
      else
        pathObject = path.parse(filePath)

      # 2. If match path extension then open
      if ItemSerializer.getMimeTypeForURI(pathObject.base)
        Outline ?= require('./core/outline')
        OutlineEditor ?= require('./editor/outline-editor')
        Outline.getOutlineForPath(path.format(pathObject)).then (outline) ->
          if outline
            new OutlineEditor(outline, options)
          else
            null

      # 3. Else strip off any query params and try again
      else
        urlObject = url.parse(pathObject.base, true)
        if ItemSerializer.getMimeTypeForURI(urlObject.pathname)
          options.hash ?= (urlObject.hash or '#').substr(1)
          options[key] ?= value for key, value of urlObject.query
          pathObject.base = urlObject.pathname
          openPromise = atom.workspace.open(path.format(pathObject), options)
          openPromise.then (editor) ->
            editor.updateOptions?(options)
          openPromise
        else
          null

    @subscriptions.add atom.packages.onDidActivatePackage (pack) ->
      if pack.name is 'foldingtext-for-atom'
        if process.platform is 'darwin'
          path ?= require 'path'
          exec = require('child_process').exec
          packagePath = atom.packages.getActivePackage('foldingtext-for-atom').path
          FoldingTextHelperPath = path.join(packagePath, 'native', 'darwin', 'FoldingTextHelper.app')

          # Launch FoldingTextHelper.app so it will be found by launch
          # services, export .ftml UTIs, and set Atom as default app for .ftml
          lsregister = '/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister'
          exec "#{lsregister} FoldingTextHelperPath", (error, stdout, stderr) ->
            exec "touch #{FoldingTextHelperPath}", (error, stdout, stderr) ->
              console.log "touch: #{error} #{stdout} #{stderr}"
              exec 'defaults read com.apple.LaunchServices', (error, stdout, stderr) ->
                console.log "read: #{error} #{stdout} #{stderr}"
                if error or stdout.indexOf('com.foldingtext.ftml') is -1
                  exec 'defaults write com.apple.LaunchServices LSHandlers -array-add \'{ LSHanderContentType = "com.foldingtext.ftml"; LSHandlerRoleAll = "com.github.atom"; }\'', (error, stdout, stderr) ->
                    console.log "read: #{error} #{stdout} #{stderr}"                

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
