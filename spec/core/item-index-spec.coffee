loadOutlineFixture = require '../load-outline-fixture'
ItemIndex = require '../../lib/core/item-index'

describe 'ItemIndex', ->
  [itemIndex, indexSubscription, itemIndexDidChangeExpects, outline, outlineSubscription, outlineDidChangeExpects, root, one, two, three, four, five, six] = []

  beforeEach ->
    {outline, root, one, two, three, four, five, six} = loadOutlineFixture()
    itemIndex = new ItemIndex(outline.root)
    outlineSubscription = outline.onDidChange (mutation) ->
      if outlineDidChangeExpects?.length
        exp = outlineDidChangeExpects.shift()
        exp(mutation)

    indexSubscription = itemIndex.onDidChange (e) ->
      if itemIndexDidChangeExpects?.length
        exp = itemIndexDidChangeExpects.shift()
        exp(e)

  afterEach ->
    expect(outlineDidChangeExpects?.length).toBeFalsy()
    outlineDidChangeExpects = null
    outlineSubscription.dispose()
    expect(itemIndexDidChangeExpects?.length).toBeFalsy()
    itemIndexDidChangeExpects = null
    indexSubscription.dispose()
    itemIndex.destroy()

  it 'can be fully emptied', ->
    one.removeFromParent()
    expect(itemIndex.getString()).toBe('')
    expect(itemIndex.getLineCount()).toBe(0)
    expect(itemIndex.getLength()).toBe(0)
    expect(outline.root.firstChild).toBe(null)

  describe 'Outline to Index', ->

    it 'maps items to item spans', ->
      itemIndex.toString().should.equal('(one\n/1)(two\n/2)(three\n/3)(four\n/4)(five\n/5)(six/6)')

    it 'can change the item that is mapped', ->
      itemIndex.setItem(two)
      itemIndex.toString().should.equal('(three\n/3)(four/4)')

    it 'updates index span when item text changes', ->
      one.bodyText = 'moose'
      one.replaceBodyTextInRange('s', 5, 0)
      one.appendBodyText('!')
      itemIndex.toString().should.equal('(mooses!\n/1)(two\n/2)(three\n/3)(four\n/4)(five\n/5)(six/6)')

    it 'adds index spans when item is added to outline', ->
      newItem = outline.createItem('new')
      newItem.id = 'a'
      two.appendChild(newItem)
      itemIndex.toString().should.equal('(one\n/1)(two\n/2)(three\n/3)(four\n/4)(new\n/a)(five\n/5)(six/6)')

      newItem = outline.createItem('new')
      newItem.id = 'b'
      newItemChild = outline.createItem('new child')
      newItemChild.id = 'bchild'
      newItem.appendChild(newItemChild)
      five.appendChild(newItem)
      itemIndex.toString().should.equal('(one\n/1)(two\n/2)(three\n/3)(four\n/4)(new\n/a)(five\n/5)(six\n/6)(new\n/b)(new child/bchild)')

    it 'removes index spans when item is removed from outline', ->
      two.removeFromParent()
      itemIndex.toString().should.equal('(one\n/1)(five\n/5)(six/6)')
      six.removeFromParent()
      itemIndex.toString().should.equal('(one\n/1)(five/5)')
      five.removeFromParent()
      itemIndex.toString().should.equal('(one/1)')
      one.removeFromParent()
      itemIndex.toString().should.equal('')

  describe 'Index to Outline', ->

    it 'update item text when span text changes from start', ->
      itemIndex.deleteRange(0, 1)
      itemIndex.toString().should.equal('(ne\n/1)(two\n/2)(three\n/3)(four\n/4)(five\n/5)(six/6)')

    it 'update item text when span text changes from middle', ->
      itemIndex.deleteRange(1, 1)
      itemIndex.toString().should.equal('(oe\n/1)(two\n/2)(three\n/3)(four\n/4)(five\n/5)(six/6)')

    it 'update item text when span text changes from end', ->
      itemIndex.deleteRange(2, 1)
      itemIndex.toString().should.equal('(on\n/1)(two\n/2)(three\n/3)(four\n/4)(five\n/5)(six/6)')

    it 'adds item when newline is inserted into index', ->
      itemIndex.insertString(1, 'z\nz')
      one.nextItem.id = 'a'
      itemIndex.toString().should.equal('(oz\n/1)(zne\n/a)(two\n/2)(three\n/3)(four\n/4)(five\n/5)(six/6)')

    it 'adds multiple items when multiple newlines are inserted into index', ->
      itemIndex.insertString(1, '\nz\nz\n')
      one.nextItem.id = 'a'
      one.nextItem.nextItem.id = 'b'
      one.nextItem.nextItem.nextItem.id = 'c'
      itemIndex.toString().should.equal('(o\n/1)(z\n/a)(z\n/b)(ne\n/c)(two\n/2)(three\n/3)(four\n/4)(five\n/5)(six/6)')

    it 'removes item when newline is removed', ->
      itemIndex.deleteRange(3, 1)
      itemIndex.toString().should.equal('(onetwo\n/1)(three\n/3)(four\n/4)(five\n/5)(six/6)')

    it 'remove item in outline when span is removed', ->
      itemIndex.removeSpans(0, 1)
      itemIndex.toString().should.equal('(two\n/2)(three\n/3)(four\n/4)(five\n/5)(six/6)')

    it 'add item in outline when span is added', ->
      span = itemIndex.createSpan('new')
      itemIndex.insertSpans(2, [span])
      span.item.id = 'NEWID'
      itemIndex.toString(false).should.equal('(one\n/1)(two\n/2)(new\n/NEWID)(three\n/3)(four\n/4)(five\n/5)(six/6)')

    describe 'Generate Index Mutations', ->

      it 'should generate mutation for item body text change', ->
        itemIndexDidChangeExpects = [
          (e) ->
            e.location.should.equal(0)
            e.replacedLength.should.equal(3)
            e.insertedString.should.equal('hello')
          (e) ->
            e.location.should.equal(21)
            e.replacedLength.should.equal(4)
            e.insertedString.should.equal('moose')
        ]
        one.bodyText = 'hello'
        five.bodyText = 'moose'

    describe 'Generate Outline Mutations', ->

      it 'should generate mutation for simple text insert', ->
        outlineDidChangeExpects = [
          (mutation) ->
            expect(mutation.type).toBe('bodyText')
            expect(mutation.replacedText.getString()).toBe('')
            expect(mutation.insertedTextLocation).toBe(0)
            expect(mutation.insertedTextLength).toBe(5)
        ]
        itemIndex.insertString(0, 'hello')
        one.bodyText.should.equal('helloone')
        one.depth.should.equal(1)

      it 'should generate mutation for simple text delete', ->
        outlineDidChangeExpects = [
          (mutation) ->
            expect(mutation.type).toBe('bodyText')
            expect(mutation.replacedText.getString()).toBe('o')
            expect(mutation.insertedTextLocation).toBe(0)
            expect(mutation.insertedTextLength).toBe(0)
        ]
        itemIndex.deleteRange(0, 1)
        one.bodyText.should.equal('ne')
        one.depth.should.equal(1)

      it 'should generate mutation for simple text replace', ->
        outlineDidChangeExpects = [
          (mutation) ->
            expect(mutation.type).toBe('bodyText')
            expect(mutation.replacedText.getString()).toBe('o')
            expect(mutation.insertedTextLocation).toBe(0)
            expect(mutation.insertedTextLength).toBe(1)
        ]
        itemIndex.replaceRange(0, 1, 'b')
        one.bodyText.should.equal('bne')
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
        one.bodyText = 'hello'

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
        expect(item.bodyText).toBe('one')
        expect(item.depth).toBe(2)

      it 'should generate mutation for delete tab from front', ->
        buffer.setTextInRange('\t', [[0, 0], [0, 0]])

        buffer.setTextInRange('', [[0, 0], [0, 1]])
        expect(item.bodyText).toBe('one')
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