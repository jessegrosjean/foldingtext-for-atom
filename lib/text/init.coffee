OutlineBuffer = require './outline/outline-buffer'

atom.workspace.observeTextEditors (textEditor) ->
  textBuffer = textEditor.getBuffer()

  outlineBuffer = new OutlineBuffer()
  outlineBuffer.outline.root.appendChild(outlineBuffer.outline.createItem(''))
  outlineBuffer.setTextInRange(textBuffer.getText(), [[0, 0], [0, 0]])

  ignoreOutlineBufferChanges = 0
  ignoreTextBufferChanges = 0

  outlineBuffer.onDidChange (e) ->
    if not ignoreOutlineBufferChanges
      ignoreTextBufferChanges++
      textBuffer.setTextInRange(e.oldRange, e.newText)
      ignoreTextBufferChanges--

  textBuffer.onDidChange (e) ->
    if not ignoreTextBufferChanges
      ignoreOutlineBufferChanges++
      outlineBuffer.setTextInRange(e.newText, e.oldRange)
      ignoreOutlineBufferChanges--

  outline = outlineBuffer.outline
  outline.root.firstChild.bodyText = 'hello'
  outline.root.firstChild.appendChild outline.createItem('Moose')
  outline.root.firstChild.appendChild outline.createItem('Mouse')
  outline.root.firstChild.appendChild outline.createItem('Mice')
  outline.root.firstChild.bodyText = 'hello'
  outline.root.appendChild(outline.root.firstChild.cloneItem())

  atom.commands.add 'atom-workspace', 'birch:hoist', ->
    row = textEditor.getSelectedBufferRange().start.row
    item = outlineBuffer.getLine(row).item
    outlineBuffer.setHoistedItem(item)

  atom.commands.add 'atom-workspace', 'birch:un-hoist', ->
    outlineBuffer.setHoistedItem(null)