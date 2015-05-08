# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

FoldingTextService = require '../../foldingtext-service'

toggleStatus = (editor, status) ->
  outline = editor.outline
  undoManager = outline.undoManager
  selectedItems = editor.selection.items
  firstItem = selectedItems[0]

  if firstItem
    if firstItem.getAttribute('data-status') is status
      status = undefined

    outline.beginUpdates()
    undoManager.beginUndoGrouping()
    for each in selectedItems
      each.setAttribute('data-status', status)
    undoManager.endUndoGrouping()
    outline.endUpdates()

FoldingTextService.eventRegistery.listen '.bstatus',
  click: (e) ->
    status = e.target.dataset.status
    outlineEditor = FoldingTextService.OutlineEditor.findOutlineEditor e.target
    outlineEditor.setSearch "@status = #{status}"
    e.stopPropagation()
    e.preventDefault()

FoldingTextService.observeOutlineEditors (editor) ->
  editor.addSearchAttributeShortcut 'status', 'data-status'
  editor.addItemBadgeRenderer (item, addBadgeElement) ->
    if status = item.getAttribute 'data-status'
      a = document.createElement 'A'
      a.className = 'bstatus'
      a.setAttribute 'data-status', status
      addBadgeElement a

atom.commands.add 'ft-outline-editor',
  'outline-editor:toggle-status-todo': -> toggleStatus @editor, 'todo'
  'outline-editor:toggle-status-waiting': -> toggleStatus @editor, 'waiting'
  'outline-editor:toggle-status-active': -> toggleStatus @editor, 'active'
  'outline-editor:toggle-status-complete': -> toggleStatus @editor, 'complete'

atom.keymaps.add 'status-bindings',
  'ft-outline-editor':
    'ctrl-space': 'outline-editor:toggle-status-complete'
  'ft-outline-editor.outlineMode':
    's t': 'outline-editor:toggle-status-todo'
    's w': 'outline-editor:toggle-status-waiting'
    's a': 'outline-editor:toggle-status-active'
    's c': 'outline-editor:toggle-status-complete'
    'space': 'outline-editor:toggle-status-complete'