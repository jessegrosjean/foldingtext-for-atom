OutlineBuffer = require '../../lib/text/outline/outline-buffer'
{CompositeDisposable} = require 'atom'
Range = require '../../lib/text/range'
Line = require '../../lib/text/line'

describe 'OutlineBuffer', ->
  [outline, subscription, mutationExpects, buffer, lines] = []

  beforeEach ->
    buffer = new OutlineBuffer()
    outline = buffer.outline
    subscription = outline.onDidChange (mutation) ->
      if mutationExpects?.length
        exp = mutationExpects.shift()
        exp(mutation)

  afterEach ->
    mutationExpects = null
    subscription.dispose()
    buffer.destroy()
    outline.destroy()

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

    describe 'Hoisted Item', ->

      it 'should hoist item', ->
        outline.root.appendChild(outline.createItem(''))
        buffer.setTextInRange('one\n\ttwo\nthree', [[0, 0], [0, 0]])
        buffer.setHoistedItem(outline.root.firstChild)
        expect(buffer.getText()).toBe('two')

      it 'should hoist item with no children', ->
        outline.root.appendChild(outline.createItem(''))
        buffer.setTextInRange('one\n\ttwo\nthree', [[0, 0], [0, 0]])
        buffer.setHoistedItem(outline.root.firstChild.firstChild)
        expect(buffer.getText()).toBe('')

      it 'should not update buffer when items are added outide hoisted item', ->
        outline.root.appendChild(outline.createItem(''))
        buffer.setTextInRange('one\n\ttwo\nthree', [[0, 0], [0, 0]])
        buffer.setHoistedItem(outline.root.firstChild)
        outline.root.appendChild(outline.createItem('not me!'))
        expect(buffer.getText()).toBe('two')

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

    describe 'Delete Text in Buffer Line', ->
      [item] = []

      beforeEach ->
        item = outline.createItem('one')
        item.indent = 3
        outline.insertItemBefore(item, null)

      it 'should delete text fully in tabs range', ->
        buffer.setTextInRange('', [[0, 0], [0, 2]])
        expect(item.bodyText).toBe('one')
        expect(item.depth).toBe(1)

      it 'should delete text overlapping tabs range', ->
        buffer.setTextInRange('', [[0, 1], [0, 4]])
        expect(item.bodyText).toBe('e')
        expect(item.depth).toBe(2)

      it 'should delete text overlapping tabs range and colliding with body text tabs', ->
        item.bodyText = 'on\t\te'
        buffer.setTextInRange('', [[0, 1], [0, 4]])
        expect(item.bodyText).toBe('e')
        expect(item.depth).toBe(4)

      it 'should delete text fully in body range', ->
        mutationExpects = [
          (mutation) ->
            expect(mutation.type).toBe('bodyText')
            expect(mutation.replacedText.getString()).toBe('ne')
            expect(mutation.insertedTextLocation).toBe(1)
            expect(mutation.insertedTextLength).toBe(0)
        ]
        buffer.setTextInRange('', [[0, 3], [0, 5]])
        expect(item.bodyText).toBe('o')
        expect(item.depth).toBe(3)

      it 'should delete text bordering body range', ->
        mutationExpects = [
          (mutation) ->
            expect(mutation.type).toBe('bodyText')
            expect(mutation.replacedText.getString()).toBe('on')
            expect(mutation.insertedTextLocation).toBe(0)
            expect(mutation.insertedTextLength).toBe(0)
        ]
        buffer.setTextInRange('', [[0, 2], [0, 4]])
        expect(item.bodyText).toBe('e')
        expect(item.depth).toBe(3)

      it 'should delete text bordering body range and colliding with body text tabs', ->
        item.bodyText = 'on\te'
        buffer.setTextInRange('', [[0, 2], [0, 4]])
        expect(item.bodyText).toBe('e')
        expect(item.depth).toBe(4)

    describe 'Insert Text in Buffer Line', ->
      [item] = []

      beforeEach ->
        item = outline.createItem('one')
        item.indent = 3
        outline.insertItemBefore(item, null)

      it 'should insert text fully in tabs range', ->
        buffer.setTextInRange('\t', [[0, 1], [0, 1]])
        expect(item.bodyText).toBe('one')
        expect(item.depth).toBe(4)

      it 'should insert text fully in body text range', ->
        buffer.setTextInRange('new', [[0, 3], [0, 3]])
        expect(item.bodyText).toBe('onewne')
        expect(item.depth).toBe(3)

      it 'should insert text in empty line with single tab', ->
        item.indent = 2
        item.bodyText = ''
        buffer.setTextInRange('a', [[0, 1], [0, 1]])
        expect(item.bodyText).toBe('a')
        expect(item.depth).toBe(2)

    describe 'Generate Minimal Outline Mutations', ->
      [item] = []

      beforeEach ->
        item = outline.createItem('one')
        outline.root.appendChild(item)

      it 'should generate mutation for simple text replace', ->
        mutationExpects = [
          (mutation) ->
            expect(mutation.type).toBe('bodyText')
            expect(mutation.replacedText.getString()).toBe('o')
            expect(mutation.insertedTextLocation).toBe(0)
            expect(mutation.insertedTextLength).toBe(0)
          (mutation) ->
            expect(mutation.type).toBe('bodyText')
            expect(mutation.replacedText.getString()).toBe('')
            expect(mutation.insertedTextLocation).toBe(0)
            expect(mutation.insertedTextLength).toBe(1)
        ]
        buffer.setTextInRange('b', [[0, 0], [0, 1]])
        expect(item.bodyText).toBe('bne')
        expect(item.depth).toBe(1)

      it 'should generate mutation for insert tab in front', ->
        mutationExpects = [
          (mutation) ->
            expect(mutation.type).toBe('children')
            expect(mutation.removedItems[0]).toBe(item)
          (mutation) ->
            expect(mutation.type).toBe('attribute')
            expect(mutation.attributeName).toBe('indent')
            expect(mutation.attributeOldValue).toBe('2')
          (mutation) ->
            expect(mutation.type).toBe('children')
            expect(mutation.addedItems[0]).toBe(item)
          (mutation) ->
            expect(mutation.type).toBe('attribute')
            expect(mutation.attributeOldValue).toBeNull()
            expect(mutation.target.getAttribute(mutation.attributeName)).toBe('2')
        ]
        buffer.setTextInRange('\t', [[0, 0], [0, 0]])
        expect(item.bodyText).toBe('one')
        expect(item.depth).toBe(2)

      it 'should generate mutation for delete tab from front', ->
        buffer.setTextInRange('\t', [[0, 0], [0, 0]])

        buffer.setTextInRange('', [[0, 0], [0, 1]])
        expect(item.bodyText).toBe('one')
        expect(item.depth).toBe(1)