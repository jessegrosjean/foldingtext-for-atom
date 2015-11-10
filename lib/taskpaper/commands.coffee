{stopEventPropagation} = require '../core/util/dom'
Item = require '../core/item'
moment = require 'moment'

archiveDone = (e, editor) ->
  outline = editor.itemBuffer.outline
  undoManager = outline.undoManager
  archive = outline.evaluateItemPath("//@text = Archive:")[0]
  selectedItemRange = editor.getSelectedItemRange()
  startItem = selectedItemRange.startItem
  endItem = selectedItemRange.endItem
  doneItems = Item.getCommonAncestors(outline.evaluateItemPath("//@done except //@text = Archive://@done"))
  removeExtraTags = e?.detail.removeExtraTags
  addProjectTag = e?.detail.addProjectTag

  undoManager.beginUndoGrouping()
  outline.beginChanges()

  unless archive
    outline.root.appendChild(archive = outline.createItem('Archive:'))

  for each in doneItems
    if removeExtraTags
      for eachName in each.attributeNames
        if eachName.indexOf('data-') is 0 and eachName isnt 'data-type' and eachName isnt 'data-done'
          each.removeAttribute(eachName)

    if addProjectTag
      ancestor = each.parent
      while ancestor and ancestor.getAttribute('data-type') isnt 'project'
        ancestor = ancestor.parent
      if ancestor
        each.setAttribute('data-project', ancestor.bodyString.substr(0, ancestor.bodyString.length - 1))

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
  'outline-editor:toggle-done': (e) ->
    if e.detail.includeDate
      value = moment().format('YYYY-MM-DD')
    @editor.toggleAttribute('data-done', value)
  'outline-editor:toggle-today': (e) -> @editor.toggleAttribute('data-today')
  'outline-editor:clear-tags': (e) -> clearTags(@editor)
  'outline-editor:archive-done': (e) -> archiveDone(e, @editor)
  'outline-editor:new-task': (e) ->
    task = @editor.insertItem('- New Task')
    @editor.setSelectedItemRange(task, 2, task, task.bodyString.length)
  'outline-editor:new-note': (e) ->
    note = @editor.insertItem('New Note')
    @editor.setSelectedItemRange(note, 0, note, note.bodyString.length)
  'outline-editor:new-project': (e) ->
    project = @editor.insertItem('New Project:')
    @editor.setSelectedItemRange(project, 0, project, project.bodyString.length - 1)
