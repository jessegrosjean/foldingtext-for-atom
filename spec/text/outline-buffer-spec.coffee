OutlineBuffer = require '../../lib/text/outline/outline-buffer'
Range = require '../../lib/text/range'
Line = require '../../lib/text/line'

fdescribe 'OutlineBuffer', ->
  [outline, buffer, lines] = []

  beforeEach ->
    buffer = new OutlineBuffer()
    outline = buffer.outline

  describe 'Init', ->

    it 'starts empty', ->
      expect(buffer.getText()).toBe('')
      expect(buffer.getLineCount()).toBe(0)
      expect(buffer.getCharacterCount()).toBe(0)
      expect(outline.root.firstChild).toBe(undefined)

  describe 'Outline Changes', ->

    describe 'Body Text', ->

      it 'updates buffer when item text changes', ->
        item = outline.createItem('one')
        outline.root.appendChild(item)
        item.replaceBodyTextInRange('b', 0, 1)
        expect(buffer.getText()).toBe('bne')
        expect(buffer.getLineCount()).toBe(1)
        expect(buffer.getCharacterCount()).toBe(3)

    describe 'Children', ->

      it 'updates buffer when outline appends items', ->
        outline.root.appendChild(outline.createItem('one'))
        outline.root.appendChild(outline.createItem('two'))
        expect(buffer.getText()).toBe('one\ntwo')
        expect(buffer.getLineCount()).toBe(2)
        expect(buffer.getCharacterCount()).toBe(7)

      it 'updates buffer when outline inserts items', ->
        outline.root.insertChildBefore(outline.createItem('two'))
        outline.root.insertChildBefore(outline.createItem('one'), outline.root.firstChild)
        expect(buffer.getText()).toBe('one\ntwo')
        expect(buffer.getLineCount()).toBe(2)
        expect(buffer.getCharacterCount()).toBe(7)

      it 'updates buffer when outline inserts items with children', ->
        one = outline.createItem('one')
        one.appendChild(outline.createItem('two'))
        outline.root.appendChild(one)
        expect(buffer.getText()).toBe('one\n\ttwo')
        expect(buffer.getLineCount()).toBe(2)
        expect(buffer.getCharacterCount()).toBe(8)

      it 'updates buffer when outline removes items', ->
        outline.root.appendChild(outline.createItem(''))
        buffer.setTextInRange('one\n\ttwo\nthree', [[0, 0], [0, 0]])
        outline.root.firstChild.firstChild.removeFromParent()
        expect(buffer.getText()).toBe('one\nthree')
        expect(buffer.getLineCount()).toBe(2)
        expect(buffer.getCharacterCount()).toBe(9)

      it 'updates buffer when outline removes items with children', ->
        outline.root.appendChild(outline.createItem(''))
        buffer.setTextInRange('one\n\ttwo\nthree', [[0, 0], [0, 0]])
        outline.root.firstChild.removeFromParent()
        expect(buffer.getText()).toBe('three')
        expect(buffer.getLineCount()).toBe(1)
        expect(buffer.getCharacterCount()).toBe(5)

  describe 'Buffer Changes', ->

    it 'updates item text when buffer changes', ->
      item = outline.createItem('one')
      outline.root.appendChild(item)
      buffer.setTextInRange('b', [[0, 0], [0, 1]])
      expect(buffer.getText()).toBe('bne')
      expect(buffer.getLineCount()).toBe(1)
      expect(buffer.getCharacterCount()).toBe(3)

    it 'adds items when buffer adds newlines', ->
      item = outline.createItem('one')
      outline.root.appendChild(item)
      buffer.setTextInRange('\n', [[0, 3], [0, 3]])
      expect(buffer.getText()).toBe('one\n')
      expect(buffer.getLineCount()).toBe(2)
      expect(buffer.getCharacterCount()).toBe(4)

    it 'adds multiple items when buffer adds multiple lines', ->
      item = outline.createItem('')
      outline.root.appendChild(item)
      buffer.setTextInRange('one\ntwo\n\t\tthree\n\tfour\nfive', [[0, 0], [0, 0]])
      expect(buffer.getText()).toBe('one\ntwo\n\t\tthree\n\tfour\nfive')
      expect(buffer.getLineCount()).toBe(5)
      expect(buffer.getCharacterCount()).toBe(26)

    it 'removes multiple items when buffer removes multiple lines', ->
      item = outline.createItem('')
      outline.root.appendChild(item)
      buffer.setTextInRange('one\ntwo\n\t\tthree\n\tfour\nfive', [[0, 0], [0, 0]])
      buffer.setTextInRange('', [[0, 2], [4, 3]])
      expect(buffer.getText()).toBe('one')
      expect(buffer.getLineCount()).toBe(1)
      expect(buffer.getCharacterCount()).toBe(3)
