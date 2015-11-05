{stopEventPropagation} = require '../core/util/dom'
Item = require '../core/item'

archiveDone = (editor) ->
  outline = editor.itemBuffer.outline
  undoManager = outline.undoManager
  archive = outline.evaluateItemPath("//@text = Archive:")[0]
  selectedItemRange = editor.getSelectedItemRange()
  startItem = selectedItemRange.startItem
  endItem = selectedItemRange.endItem
  doneItems = Item.getCommonAncestors(outline.evaluateItemPath("//@done except //@text = Archive://@done"))

  undoManager.beginUndoGrouping()
  outline.beginChanges()

  unless archive
    outline.root.appendChild(archive = outline.createItem('Archive:'))

  for each in doneItems
    if (each is startItem or each.contains(startItem)) or (each is endItem or each.contains(endItem))
      selectedItemRange = startItem: editor.getPreviousVisibleItem(startItem), startOffset: -1

  archive.insertChildrenBefore(doneItems, archive.firstChild)

  outline.endChanges()
  undoManager.endUndoGrouping()
  editor.setSelectedItemRange(selectedItemRange)

clearTags = (editor) ->
  outline = editor.itemBuffer.outline
  undoManager = outline.undoManager
  selectedItemRange = editor.getSelectedItemRange()
  startItem = selectedItemRange.startItem
  endItem = selectedItemRange.endItem

  undoManager.beginUndoGrouping()
  outline.beginChanges()

  each = startItem
  end = endItem.nextItem
  while each isnt end
    for eachName in each.attributeNames
      if eachName.indexOf('data-') is 0 and eachName isnt 'data-type'
        each.removeAttribute(eachName)
    each = each.nextItem

  outline.endChanges()
  undoManager.endUndoGrouping()
  editor.setSelectedItemRange(selectedItemRange)

atom.commands.add 'outline-editor', stopEventPropagation
  'outline-editor:toggle-done': -> @editor.toggleAttribute('data-done')
  'outline-editor:toggle-today': -> @editor.toggleAttribute('data-today')
  'outline-editor:clear-tags': -> clearTags(@editor)
  'outline-editor:archive-done': -> archiveDone(@editor)
  'outline-editor:new-task': ->
    task = @editor.insertItem('- New Task')
    @editor.setSelectedItemRange(task, 2, task, task.bodyString.length)
  'outline-editor:new-note': ->
    note = @editor.insertItem('New Note')
    @editor.setSelectedItemRange(note, 0, note, note.bodyString.length)
  'outline-editor:new-project': ->
    project = @editor.insertItem('New Project:')
    @editor.setSelectedItemRange(project, 0, project, project.bodyString.length - 1)
