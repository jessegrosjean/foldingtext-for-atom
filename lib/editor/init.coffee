OutlineAttributedString = require './outline-attributed-string'

atom.workspace.observeTextEditors (textEditor) ->
  textBuffer = textEditor.getBuffer()

  outlineAttributedString = new OutlineBuffer()
  outlineAttributedString.outline.root.appendChild(outlineAttributedString.outline.createItem(''))
  outlineAttributedString.setTextInRange(textBuffer.getText(), [[0, 0], [0, 0]])

  ignoreOutlineAttributedStringChanges = 0
  ignoreTextBufferChanges = 0

  outlineAttributedString.onDidChange (e) ->
    if not ignoreOutlineAttributedStringChanges
      ignoreTextBufferChanges++
      textBuffer.setTextInRange(e.oldRange, e.newText)
      ignoreTextBufferChanges--

  textBuffer.onDidChange (e) ->
    if not ignoreTextBufferChanges
      ignoreOutlineAttributedStringChanges++
      outlineAttributedString.setTextInRange(e.newText, e.oldRange)
      ignoreOutlineAttributedStringChanges--

  outline = outlineAttributedString.outline
  outline.root.firstChild.bodyText = 'hello'
  outline.root.firstChild.appendChild outline.createItem('Moose')
  outline.root.firstChild.appendChild outline.createItem('Mouse')
  outline.root.firstChild.appendChild outline.createItem('Mice')
  outline.root.firstChild.bodyText = 'hello'
  outline.root.appendChild(outline.root.firstChild.cloneItem())

  atom.commands.add 'atom-workspace', 'birch:hoist', ->
    row = textEditor.getSelectedBufferRange().start.row
    item = outlineAttributedString.getLine(row).item
    outlineAttributedString.setItem(item)

  atom.commands.add 'atom-workspace', 'birch:un-hoist', ->
    outlineAttributedString.setItem(null)