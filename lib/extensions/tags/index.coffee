# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

FoldingTextService = require '../../foldingtext-service'
TokenInputElement = require '../ui/token-input-element'
ListInputElement = require '../ui/list-input-element'
{CompositeDisposable} = require 'atom'

FoldingTextService.observeOutlineEditors (editor) ->
  editor.addSearchAttributeShortcut 'tags', 'data-tags'
  editor.addItemBadgeRenderer (item, addBadgeElement) ->
    if tags = item.getAttribute 'data-tags', true
      for each in tags
        each = each.trim()
        a = document.createElement 'A'
        a.className = 'btag'
        a.setAttribute 'data-tag', each
        a.textContent = each
        addBadgeElement a

FoldingTextService.eventRegistery.listen '.btag',
  click: (e) ->
    tag = e.target.textContent
    outlineEditor = FoldingTextService.OutlineEditor.findOutlineEditor e.target
    outlineEditor.setSearch "##{tag}"
    e.stopPropagation()
    e.preventDefault()

editTags = (editor) ->
  savedSelection = editor.selection
  selectedItems = savedSelection.items
  item = savedSelection.focusItem
  return unless selectedItems.length > 0

  outlineTagsMap = {}
  for eachItem in editor.outline.evaluateItemPath('#')
    for eachTag in eachItem.getAttribute('data-tags', true) or []
      outlineTagsMap[eachTag] = true

  selectedTagsMap = {}
  for eachItem in selectedItems
    for eachTag in eachItem.getAttribute('data-tags', true) or []
      selectedTagsMap[eachTag] = true

  addedTokens = {}
  deletedTokens = {}
  tokenInput = document.createElement 'ft-token-input'
  tokenInput.setPlaceholderText 'Tag…'
  tokenInput.tokenizeText(Object.keys(selectedTagsMap).join(','))

  tokenInput.setDelegate
    didAddToken: (token) ->
      outlineTagsMap[token] = true
      addedTokens[token] = true
      delete deletedTokens[token]

    didDeleteToken: (token) ->
      delete addedTokens[token]
      deletedTokens[token] = true

    cancelled: ->
      tokenInputPanel.destroy()

    restoreFocus: ->
      editor.focus()
      editor.moveSelectionRange savedSelection

    confirm: ->
      text = tokenInput.getText()
      if text
        tokenInput.tokenizeText()
      else
        if selectedItems.length is 1
          selectedItems[0].setAttribute('data-tags', tokenInput.getTokens())
        else if selectedItems.length > 1
          editor.outline.beginUpdates()
          for each in selectedItems
            eachTags = each.getAttribute('data-tags', true) or []
            changed = false
            for eachDeleted of deletedTokens
              if eachDeleted in eachTags
                eachTags.splice(eachTags.indexOf(eachDeleted), 1)
                changed = true
            for eachAdded of addedTokens
              unless eachAdded in eachTags
                eachTags.push eachAdded
                changed = true
            if changed
              each.setAttribute('data-tags', eachTags)

          editor.outline.endUpdates()

        tokenInputPanel.destroy()
        @restoreFocus()

  tokenInputPanel = atom.workspace.addPopoverPanel
    item: tokenInput
    className: 'ft-text-input-panel'
    target: -> editor.getClientRectForItemOffset(item, item.bodyText.length)
    viewport: -> editor.outlineEditorElement.getBoundingClientRect()
    placement: 'bottom'

  tokenInput.focusTextEditor()

clearTags = (editor) ->
  outline = editor.outline
  undoManager = outline.undoManager
  selectedItems = editor.selection.items

  if selectedItems.length
    outline.beginUpdates()
    undoManager.beginUndoGrouping()
    for each in selectedItems
      each.removeAttribute 'data-tags'
    outline.endUpdates()
    undoManager.endUndoGrouping()

atom.commands.add 'ft-outline-editor',
  'outline-editor:edit-tags': -> editTags @editor
  'outline-editor:clear-tags': -> clearTags @editor

atom.commands.add 'ft-outline-editor .btag',
  'outline-editor:delete-tag': (e) ->
    tag = @textContent
    editor = FoldingTextService.OutlineEditor.findOutlineEditor this
    item = editor.selection.focusItem
    tags = item.getAttribute 'data-tags', true
    if tag in tags
      tags.splice(tags.indexOf(tag), 1)
      item.setAttribute 'data-tags', tags
    e.stopPropagation()
    e.preventDefault()

atom.keymaps.add 'tags-bindings',
  'ft-outline-editor':
    'cmd-shift-t': 'outline-editor:edit-tags'
  'ft-outline-editor.outlineMode':
    't': 'outline-editor:edit-tags'

#atom.contextMenu.add
#  'ft-outline-editor .btag': [
#    {label: 'Delete Tag', command: 'outline-editor:delete-tag'}
#  ]