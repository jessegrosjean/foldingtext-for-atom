{stopEventPropagation} = require '../core/util/dom'
Item = require '../core/item'

archiveDone = (editor) ->
  outline = editor.itemBuffer.outline
  undoManager = outline.undoManager
  archive = outline.evaluateItemPath("//@text = Archive:")[0]
  selectedItemRange = editor.getSelectedItemRange()
  doneItems = Item.getCommonAncestors(outline.evaluateItemPath("//@done except //@text = Archive://@done"))

  undoManager.beginUndoGrouping()
  outline.beginChanges()

  unless archive
    outline.root.appendChild(archive = outline.createItem('Archive:'))
  archive.insertChildrenBefore(doneItems, archive.firstChild)

  outline.endChanges()
  undoManager.endUndoGrouping()
  editor.setSelectedItemRange(selectedItemRange)

atom.commands.add 'outline-editor', stopEventPropagation
  'outline-editor:toggle-done': -> @editor.toggleAttribute('data-done')
  'outline-editor:toggle-today': -> @editor.toggleAttribute('data-today')
  'outline-editor:archive-done': -> archiveDone(@editor)