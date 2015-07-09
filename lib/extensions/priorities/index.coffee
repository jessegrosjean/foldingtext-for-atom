# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

FoldingTextService = require '../../foldingtext-service'

togglePriority = (editor, priority) ->
  outline = editor.outline
  undoManager = outline.undoManager
  selectedItems = editor.selection.items
  firstItem = selectedItems[0]

  if firstItem
    if firstItem.getAttribute('data-priority') is priority
      priority = undefined

    outline.beginChanges()
    undoManager.beginUndoGrouping()
    for each in selectedItems
      each.setAttribute('data-priority', priority)
    undoManager.endUndoGrouping()
    outline.endChanges()

FoldingTextService.observeOutlineEditors (editor) ->
  editor.addItemBadgeRenderer (item, addBadgeElement) ->
    if value = item.getAttribute 'data-priority'
      span = document.createElement 'A'
      span.className = 'bpriority'
      span.setAttribute 'data-priority', value
      addBadgeElement span

FoldingTextService.eventRegistery.listen '.bpriority',
  click: (e) ->
    priority = e.target.dataset.priority
    outlineEditor = FoldingTextService.OutlineEditor.findOutlineEditor e.target
    outlineEditor.setSearch "@priority = #{priority}"
    e.stopPropagation()
    e.preventDefault()

atom.commands.add 'ft-outline-editor',
  'outline-editor:toggle-priority-1': -> togglePriority @editor, '1'
  'outline-editor:toggle-priority-2': -> togglePriority @editor, '2'
  'outline-editor:toggle-priority-3': -> togglePriority @editor, '3'
  'outline-editor:toggle-priority-4': -> togglePriority @editor, '4'
  'outline-editor:toggle-priority-5': -> togglePriority @editor, '5'
  'outline-editor:toggle-priority-6': -> togglePriority @editor, '6'
  'outline-editor:toggle-priority-7': -> togglePriority @editor, '7'
  'outline-editor:clear-priority': -> togglePriority @editor, undefined

atom.keymaps.add 'priorities-bindings',
  'ft-outline-editor.outline-mode':
    '1': 'outline-editor:toggle-priority-1'
    '2': 'outline-editor:toggle-priority-2'
    '3': 'outline-editor:toggle-priority-3'
    '4': 'outline-editor:toggle-priority-4'
    '5': 'outline-editor:toggle-priority-5'
    '6': 'outline-editor:toggle-priority-6'
    '7': 'outline-editor:toggle-priority-7'
    '0': 'outline-editor:clear-priority'