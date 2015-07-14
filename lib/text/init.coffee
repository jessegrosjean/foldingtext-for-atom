OutlineBuffer = require './outline/outline-buffer'

atom.workspace.observeTextEditors (textEditor) ->
  textBuffer = textEditor.getBuffer()

  outlineBuffer = new OutlineBuffer()
  outlineBuffer.outline.root.appendChild(outlineBuffer.outline.createItem(''))
  outlineBuffer.setTextInRange(textBuffer.getText(), [[0, 0], [0, 0]])

  outlineBuffer.onDidChange (e) ->

  textBuffer.onDidChange (e) ->
    outlineBuffer.setTextInRange(e.newText, e.oldRange)
    console.log(outlineBuffer.outline.toString())
