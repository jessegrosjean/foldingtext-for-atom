# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

foldingTextService = require '../foldingtext-service'
{Disposable, CompositeDisposable} = require 'atom'
TextInputElement = require './ui/text-input-element'
ItemPathGrammar = require './item-path-grammar'

exports.consumeStatusBarService = (statusBar) ->
  searchElement = document.createElement 'ft-text-input'
  searchElement.classList.add 'inline-block'
  searchElement.classList.add 'ft-search-status-bar-item'
  searchElement.cancelOnBlur = false
  searchElement.setPlaceholderText 'Search'
  searchElement.setGrammar new ItemPathGrammar(atom.grammars)

  clearAddon = document.createElement 'span'
  clearAddon.className = 'icon-remove-close'
  clearAddon.addEventListener 'click', (e) ->
    e.preventDefault()
    searchElement.cancel()
    searchElement.focusTextEditor()
  searchElement.addRightAddonElement clearAddon

  searchElement.setDelegate
    didChangeText: ->
      foldingTextService.getActiveOutlineEditor()?.setSearch searchElement.getText()
    restoreFocus: ->
    cancelled: ->
      editor = foldingTextService.getActiveOutlineEditor()
      if editor.getSearch()?.query
        editor?.setSearch ''
      else
        editor?.focus()
    confirm: ->
      foldingTextService.getActiveOutlineEditor()?.focus()

  searchStatusBarItem = statusBar.addLeftTile(item: searchElement, priority: 0)
  searchElement.setSizeToFit true

  activeOutlineEditorSubscriptions = null
  activeOutlineEditorSubscription = foldingTextService.observeActiveOutlineEditor (outlineEditor) ->
    activeOutlineEditorSubscriptions?.dispose()
    if outlineEditor
      update = ->
        searchQuery = outlineEditor.getSearch()?.query
        if searchQuery
          searchElement.classList.add 'active'
          clearAddon.style.display = null
        else
          searchElement.classList.remove 'active'
          clearAddon.style.display = 'none'
        unless searchElement.getText() is searchQuery
          searchElement.setText searchQuery
        searchElement.scheduleLayout()

      searchElement.style.display = null
      activeOutlineEditorSubscriptions = new CompositeDisposable()
      activeOutlineEditorSubscriptions.add outlineEditor.onDidChangeSearch -> update()
      activeOutlineEditorSubscriptions.add outlineEditor.onDidChangeHoistedItem -> update()
      update()
    else
      searchElement.style.display = 'none'

    commandsSubscriptions = new CompositeDisposable
    commandsSubscriptions.add atom.commands.add searchElement,
      'editor:copy-path': ->
        foldingTextService.getActiveOutlineEditor()?.copyPathToClipboard()
    commandsSubscriptions.add atom.commands.add 'ft-outline-editor.outlineMode',
      'core:cancel': (e) ->
        searchElement.focusTextEditor()
        e.stopPropagation()
    commandsSubscriptions.add atom.commands.add 'ft-outline-editor',
      'find-and-replace:show': (e) ->
        searchElement.focusTextEditor()
        e.stopPropagation()
      'find-and-replace:show-replace': (e) ->
        searchElement.focusTextEditor()
        e.stopPropagation()

    new Disposable ->
      activeOutlineEditorSubscription.dispose()
      activeOutlineEditorSubscriptions?.dispose()
      commandsSubscriptions.dispose()
      searchStatusBarItem.destroy()
