loadOutlineFixture = require '../load-outline-fixture'
ItemBuffer = require '../../lib/core/item-buffer'
Mutation = require '../../lib/core/mutation'

describe 'ItemBuffer', ->
  [itemBuffer, bufferSubscription, itemBufferDidChangeExpects, outline, outlineSubscription, outlineDidChangeExpects, root, one, two, three, four, five, six] = []

  beforeEach ->
    {outline, root, one, two, three, four, five, six} = loadOutlineFixture()
    itemBuffer = new ItemBuffer(outline)
    itemBuffer.setHoistedItem(outline.root)
    outlineSubscription = outline.onDidChange (mutation) ->
      if outlineDidChangeExpects?.length
        exp = outlineDidChangeExpects.shift()
        exp(mutation)

    bufferSubscription = itemBuffer.onDidChange (e) ->
      if itemBufferDidChangeExpects?.length
        exp = itemBufferDidChangeExpects.shift()
        exp(e)

  afterEach ->
    expect(outlineDidChangeExpects?.length).toBeFalsy()
    outlineDidChangeExpects = null
    outlineSubscription.dispose()
    expect(itemBufferDidChangeExpects?.length).toBeFalsy()
    itemBufferDidChangeExpects = null
    bufferSubscription.dispose()
    itemBuffer.destroy()

  it 'can be fully emptied', ->
    one.removeFromParent()
    expect(itemBuffer.getString()).toBe('')
    expect(itemBuffer.getLineCount()).toBe(0)
    expect(itemBuffer.getLength()).toBe(0)
    expect(outline.root.firstChild).toBe(null)

  describe 'Outline to Index', ->

    it 'maps items to item spans', ->
      itemBuffer.toString().should.equal('(one\n/1)(two\n/2)(three\n/3)(four\n/4)(five\n/5)(six/6)')

    it 'can change the item that is mapped', ->
      itemBuffer.setHoistedItem(two)
      itemBuffer.toString().should.equal('(three\n/3)(four/4)')

    it 'updates index span when item text changes', ->
      one.bodyString = 'moose'
      one.replaceBodyRange(5, 0, 's')
      one.appendBody('!')
      itemBuffer.toString().should.equal('(mooses!\n/1)(two\n/2)(three\n/3)(four\n/4)(five\n/5)(six/6)')

    it 'adds index spans when item is added to outline', ->
      newItem = outline.createItem('new')
      newItem.id = 'a'
      two.appendChild(newItem)
      itemBuffer.toString().should.equal('(one\n/1)(two\n/2)(three\n/3)(four\n/4)(new\n/a)(five\n/5)(six/6)')

      newItem = outline.createItem('new')
      newItem.id = 'b'
      newItemChild = outline.createItem('new child')
      newItemChild.id = 'bchild'
      newItem.appendChild(newItemChild)
      five.appendChild(newItem)
      itemBuffer.toString().should.equal('(one\n/1)(two\n/2)(three\n/3)(four\n/4)(new\n/a)(five\n/5)(six\n/6)(new\n/b)(new child/bchild)')

    it 'removes index spans when item is removed from outline', ->
      two.removeFromParent()
      itemBuffer.toString().should.equal('(one\n/1)(five\n/5)(six/6)')
      six.removeFromParent()
      itemBuffer.toString().should.equal('(one\n/1)(five/5)')
      five.removeFromParent()
      itemBuffer.toString().should.equal('(one/1)')
      one.removeFromParent()
      itemBuffer.toString().should.equal('')

  describe 'Index to Outline', ->

    it 'update item text when span text changes from start', ->
      itemBuffer.deleteRange(0, 1)
      itemBuffer.toString().should.equal('(ne\n/1)(two\n/2)(three\n/3)(four\n/4)(five\n/5)(six/6)')

    it 'update item text when span text changes from middle', ->
      itemBuffer.deleteRange(1, 1)
      itemBuffer.toString().should.equal('(oe\n/1)(two\n/2)(three\n/3)(four\n/4)(five\n/5)(six/6)')

    it 'update item text when span text changes from end', ->
      itemBuffer.deleteRange(2, 1)
      itemBuffer.toString().should.equal('(on\n/1)(two\n/2)(three\n/3)(four\n/4)(five\n/5)(six/6)')

    it 'adds item when newline is inserted into index', ->
      itemBuffer.insertString(1, 'z\nz')
      one.nextItem.id = 'a'
      itemBuffer.toString().should.equal('(oz\n/1)(zne\n/a)(two\n/2)(three\n/3)(four\n/4)(five\n/5)(six/6)')

    it 'adds multiple items when multiple newlines are inserted into index', ->
      itemBuffer.insertString(1, '\nz\nz\n')
      one.nextItem.id = 'a'
      one.nextItem.nextItem.id = 'b'
      one.nextItem.nextItem.nextItem.id = 'c'
      itemBuffer.toString().should.equal('(o\n/1)(z\n/a)(z\n/b)(ne\n/c)(two\n/2)(three\n/3)(four\n/4)(five\n/5)(six/6)')

    it 'removes item when newline is removed', ->
      itemBuffer.deleteRange(3, 1)
      itemBuffer.toString().should.equal('(onetwo\n/1)(three\n/3)(four\n/4)(five\n/5)(six/6)')

    it 'removes item when newline is removed, but preserves body attributes', ->
      itemBuffer.deleteRange(13, 1)
      itemBuffer.toString().should.equal('(one\n/1)(two\n/2)(threefour\n/3)(five\n/5)(six/6)')
      three.toString().should.equal('(3) (three)(fo)(u/B:null)(r)')

    it 'remove item in outline when span is removed', ->
      itemBuffer.removeSpans(0, 1)
      itemBuffer.toString().should.equal('(two\n/2)(three\n/3)(four\n/4)(five\n/5)(six/6)')

    it 'add item in outline when span is added', ->
      span = itemBuffer.createSpan('new')
      itemBuffer.insertSpans(2, [span])
      span.item.id = 'NEWID'
      itemBuffer.toString(false).should.equal('(one\n/1)(two\n/2)(new\n/NEWID)(three\n/3)(four\n/4)(five\n/5)(six/6)')

    describe 'Generate Index Mutations', ->

      it 'should generate mutation for item body text change', ->
        itemBufferDidChangeExpects = [
          (e) ->
            e.location.should.equal(0)
            e.replacedLength.should.equal(3)
            e.insertedString.should.equal('hello')
          (e) ->
            e.location.should.equal(21)
            e.replacedLength.should.equal(4)
            e.insertedString.should.equal('moose')
        ]
        one.bodyString = 'hello'
        five.bodyString = 'moose'

    describe 'Generate Outline Mutations', ->

      it 'should generate mutation for simple text insert', ->
        outlineDidChangeExpects = [
          (mutation) ->
            expect(mutation.type).toBe(Mutation.BODY_CHANGED)
            expect(mutation.replacedText.getString()).toBe('')
            expect(mutation.insertedTextLocation).toBe(0)
            expect(mutation.insertedTextLength).toBe(5)
        ]
        itemBuffer.insertString(0, 'hello')
        one.bodyString.should.equal('helloone')
        one.depth.should.equal(1)

      it 'should generate mutation for simple text delete', ->
        outlineDidChangeExpects = [
          (mutation) ->
            expect(mutation.type).toBe(Mutation.BODY_CHANGED)
            expect(mutation.replacedText.getString()).toBe('o')
            expect(mutation.insertedTextLocation).toBe(0)
            expect(mutation.insertedTextLength).toBe(0)
        ]
        itemBuffer.deleteRange(0, 1)
        one.bodyString.should.equal('ne')
        one.depth.should.equal(1)

      it 'should generate mutation for simple text replace', ->
        outlineDidChangeExpects = [
          (mutation) ->
            expect(mutation.type).toBe(Mutation.BODY_CHANGED)
            expect(mutation.replacedText.getString()).toBe('o')
            expect(mutation.insertedTextLocation).toBe(0)
            expect(mutation.insertedTextLength).toBe(1)
        ]
        itemBuffer.replaceRange(0, 1, 'b')
        one.bodyString.should.equal('bne')
        one.depth.should.equal(1)

###
describe 'OutlineBuffer', ->
  describe 'Outline Changes', ->

    describe 'Generate Buffer Mutations', ->
      [one, two, three] = []

      beforeEach ->
        outline.root.appendChild(one = outline.createItem('one'))
        outline.root.firstChild.appendChild(two = outline.createItem('two'))
        outline.root.appendChild(three = outline.createItem('three'))

      it 'should generate mutation for item body text change', ->
        bufferDidChangeExpects = [
          (e) ->
            expect(e.oldText).toEqual('one')
            expect(e.oldCharacterRange).toEqual(start: 0, end: 3)
            expect(e.newText).toEqual('hello')
            expect(e.newCharacterRange).toEqual(start: 0, end: 5)
        ]
        one.bodyString = 'hello'

      it 'should generate mutation for item insert', ->
        bufferDidChangeExpects = [
          (e) ->
            expect(e.oldText).toEqual('')
            expect(e.oldCharacterRange).toEqual(start: 9, end: 9)
            expect(e.newText).toEqual('\tnew!\n')
            expect(e.newCharacterRange).toEqual(start: 9, end: 15)
        ]
        one.appendChild(outline.createItem('new!'))

      it 'should generate mutation for item remove', ->
        bufferDidChangeExpects = [
          (e) ->
            expect(e.oldText).toEqual('one\n\ttwo\n')
            expect(e.oldCharacterRange).toEqual(start: 0, end: 9)
            expect(e.newText).toEqual('')
            expect(e.newCharacterRange).toEqual(start: 0, end: 0)
        ]
        one.removeFromParent()

  describe 'Buffer Changes', ->

    describe 'Generate Outline Mutations', ->
      [item] = []

      beforeEach ->
        item = outline.createItem('one')
        outline.root.appendChild(item)

      it 'should generate mutation for simple text replace', ->
        outlineDidChangeExpects = [
          (mutation) ->
            expect(mutation.type).toBe(Mutation.BODY_CHANGED)
            expect(mutation.replacedText.getString()).toBe('o')
            expect(mutation.insertedTextLocation).toBe(0)
            expect(mutation.insertedTextLength).toBe(0)
          (mutation) ->
            expect(mutation.type).toBe(Mutation.BODY_CHANGED)
            expect(mutation.replacedText.getString()).toBe('')
            expect(mutation.insertedTextLocation).toBe(0)
            expect(mutation.insertedTextLength).toBe(1)
        ]
        buffer.setTextInRange('b', [[0, 0], [0, 1]])
        expect(item.bodyString).toBe('bne')
        expect(item.depth).toBe(1)

      it 'should generate mutation for insert tab in front', ->
        outlineDidChangeExpects = [
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
        expect(item.bodyString).toBe('one')
        expect(item.depth).toBe(2)

      it 'should generate mutation for delete tab from front', ->
        buffer.setTextInRange('\t', [[0, 0], [0, 0]])

        buffer.setTextInRange('', [[0, 0], [0, 1]])
        expect(item.bodyString).toBe('one')
        expect(item.depth).toBe(1)

  describe 'Performance', ->
    it 'should load 10,000 items', ->
      lines = []
      for i in [0..(10000 / 10)]
        lines.push('project:')
        lines.push('\t- task!')
        lines.push('\t\tnote')
        lines.push('\t- task! @done')
        lines.push('\t\tnote')
        lines.push('\t- task!')
        lines.push('\t\tnote')
        lines.push('\t- task!')
        lines.push('\t\tnote')
        lines.push('\t- task!')
      lines = lines.join('\n')

      console.profile('Create Many')
      console.time('Create Many')
      buffer.setTextInRange(lines, [[0, 0], [0, 1]])
      console.timeEnd('Create Many Items')
      console.profileEnd()
###