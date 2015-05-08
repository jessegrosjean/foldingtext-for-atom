# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

foldingTextService = require '../foldingtext-service'
{Disposable, CompositeDisposable} = require 'atom'

exports.consumeStatusBarService = (statusBar) ->
  hoistElement = document.createElement 'a'
  hoistElement.className = 'ft-location-status-bar-item icon-location inline-block'
  hoistElement.addEventListener 'click', (e) ->
    foldingTextService.getActiveOutlineEditor()?.unhoist()

  locationStatusBarItem = statusBar.addLeftTile(item: hoistElement, priority: 0)

  activeOutlineEditorSubscriptions = null
  activeOutlineEditorSubscription = foldingTextService.observeActiveOutlineEditor (outlineEditor) ->
    activeOutlineEditorSubscriptions?.dispose()
    if outlineEditor
      update = ->
        hoistedItem = outlineEditor.getHoistedItem()
        hoistElement.classList.toggle 'active', not hoistedItem.isRoot

      hoistElement.style.display = null
      activeOutlineEditorSubscriptions = new CompositeDisposable()
      activeOutlineEditorSubscriptions.add outlineEditor.onDidChangeSearch -> update()
      activeOutlineEditorSubscriptions.add outlineEditor.onDidChangeHoistedItem -> update()
      update()
    else
      hoistElement.style.display = 'none'

  new Disposable ->
    activeOutlineEditorSubscription.dispose()
    activeOutlineEditorSubscriptions?.dispose()
    locationStatusBarItem.destroy()