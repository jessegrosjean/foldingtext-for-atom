OutlineEditor = require '../../lib/text/outline/outline-editor'

describe 'OutlineEditor', ->
  [outline, editor, buffer, bufferSubscription, bufferDidChangeExpects] = []

  beforeEach ->
    editor = new OutlineEditor()
    buffer = editor.outlineBuffer
    outline = buffer.outline
    bufferSubscription = buffer.onDidChange (e) ->
      if bufferDidChangeExpects?.length
        exp = bufferDidChangeExpects.shift()
        exp(e)

  afterEach ->
    expect(bufferDidChangeExpects?.length).toBeFalsy()
    bufferDidChangeExpects = null
    bufferSubscription.dispose()
    editor.destroy()

  ###
  describe 'Init', ->

    it 'starts empty', ->
      expect(buffer.getText()).toBe('')
      expect(buffer.getLineCount()).toBe(0)
      expect(buffer.getCharacterCount()).toBe(0)
      expect(outline.root.firstChild).toBe(undefined)
  ###

  describe 'Hoisted Item', ->

    it 'should hoist item', ->
      outline.root.appendChild(outline.createItem(''))
      buffer.setTextInRange('one\n\ttwo\nthree', [[0, 0], [0, 0]])
      editor.setHoistedItem(outline.root.firstChild)
      expect(buffer.getText()).toBe('two')

    it 'should hoist item with no children', ->
      outline.root.appendChild(outline.createItem(''))
      buffer.setTextInRange('one\n\ttwo\nthree', [[0, 0], [0, 0]])
      editor.setHoistedItem(outline.root.firstChild.firstChild)
      expect(buffer.getText()).toBe('')

    it 'should not update buffer when items are added outide hoisted item', ->
      outline.root.appendChild(outline.createItem(''))
      buffer.setTextInRange('one\n\ttwo\nthree', [[0, 0], [0, 0]])
      editor.setHoistedItem(outline.root.firstChild)
      outline.root.appendChild(outline.createItem('not me!'))
      expect(buffer.getText()).toBe('two')