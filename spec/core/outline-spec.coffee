loadOutlineFixture = require '../load-outline-fixture'
Outline = require '../../lib/core/outline'
path = require 'path'
fs = require 'fs'

describe 'Outline', ->
  [editor, outline, root, one, two, three, four, five, six] = []

  beforeEach ->
    {outline, root, one, two, three, four, five, six} = loadOutlineFixture()

  it 'should create item', ->
    item = outline.createItem('hello')
    item.isInOutline.should.be.false

  it 'should get item by id', ->
    item = outline.createItem('hello')
    outline.root.appendChild(item)
    outline.getItemForID(item.id).should.equal(item)

  it 'should copy item', ->
    oneCopy = outline.cloneItem(one)
    oneCopy.isInOutline.should.be.false
    oneCopy.id.should.not.equal(one.id)
    oneCopy.bodyText.should.equal('one')
    oneCopy.firstChild.bodyText.should.equal('two')
    oneCopy.firstChild.firstChild.bodyText.should.equal('three')
    oneCopy.firstChild.lastChild.bodyText.should.equal('four')
    oneCopy.lastChild.bodyText.should.equal('five')
    oneCopy.lastChild.firstChild.bodyText.should.equal('six')

  it 'should import item', ->
    outline2 = new Outline()

    oneImport = outline2.importItem(one)
    oneImport.outline.should.equal(outline2)
    oneImport.isInOutline.should.be.false
    oneImport.id.should.equal(one.id)
    oneImport.bodyText.should.equal('one')
    oneImport.firstChild.bodyText.should.equal('two')
    oneImport.firstChild.firstChild.bodyText.should.equal('three')
    oneImport.firstChild.lastChild.bodyText.should.equal('four')
    oneImport.lastChild.bodyText.should.equal('five')
    oneImport.lastChild.firstChild.bodyText.should.equal('six')

  describe 'Insert & Remove Items', ->
    it 'insert items at indent level', ->
      newItem = outline.createItem('new')
      outline.insertItemBefore(newItem, two)
      newItem.totalIndent.should.equal(1)
      newItem.previousSibling.should.equal(one)
      newItem.firstChild.should.equal(two)
      newItem.lastChild.should.equal(five)

    it 'remove item leaving children', ->
      outline.removeItem(two)
      two.isInOutline.should.equal(false)
      three.isInOutline.should.equal(true)
      three.parent.should.equal(one)
      three.totalIndent.should.equal(3)
      four.isInOutline.should.equal(true)
      four.parent.should.equal(one)
      four.totalIndent.should.equal(3)

  describe 'Search', ->
    it 'should find DOM using xpath', ->
      outline.evaluateXPath('//li', null, null, XPathResult.ANY_TYPE, null).iterateNext().should.equal(one._liOrRootUL)

    it 'should find items using xpath', ->
      items = outline.getItemsForXPath('//li')
      items.should.eql([
        one,
        two,
        three,
        four,
        five,
        six
      ])

    it 'should only return item once even if multiple xpath matches', ->
      items = outline.getItemsForXPath('//*')
      items.should.eql([
        root,
        one,
        two,
        three,
        four,
        five,
        six
      ])

  describe 'Undo', ->
    it 'should undo append child', ->
      child = outline.createItem('hello')
      one.appendChild(child)
      outline.undoManager.undo()
      expect(child.parent).toBe(undefined)

    it 'should undo remove child', ->
      one.removeChild(two)
      outline.undoManager.undo()
      two.parent.should.equal(one)

    it 'should undo move child', ->
      outline.undoManager.beginUndoGrouping()
      one.appendChild(six)
      outline.undoManager.endUndoGrouping()
      outline.undoManager.undo()
      six.parent.should.equal(five)

    it 'should undo set attribute', ->
      one.setAttribute('myattr', 'test')
      one.getAttribute('myattr').should.equal('test')
      outline.undoManager.undo()
      expect(one.getAttribute('myattr') is null).toBe(true)

    describe 'Body Text', ->
      it 'should undo set body text', ->
        one.bodyText = 'hello word'
        outline.undoManager.undo()
        one.bodyText.should.equal('one')

      it 'should undo replace body text', ->
        one.replaceBodyTextInRange('hello', 1, 1)
        one.bodyText.should.equal('ohelloe')
        outline.undoManager.undo()
        one.bodyText.should.equal('one')

      it 'should coalesce consecutive body text inserts', ->
        one.replaceBodyTextInRange('a', 1, 0)
        one.replaceBodyTextInRange('b', 2, 0)
        one.replaceBodyTextInRange('c', 3, 0)
        one.bodyText.should.equal('oabcne')
        outline.undoManager.undo()
        one.bodyText.should.equal('one')
        outline.undoManager.redo()
        one.bodyText.should.equal('oabcne')

      it 'should coalesce consecutive body text deletes', ->
        one.replaceBodyTextInRange('', 2, 1)
        one.replaceBodyTextInRange('', 1, 1)
        one.replaceBodyTextInRange('', 0, 1)
        one.bodyText.should.equal('')
        outline.undoManager.undo()
        one.bodyText.should.equal('one')
        outline.undoManager.redo()
        one.bodyText.should.equal('')

  describe 'Performance', ->
    it 'should create/copy/remove 10,000 items', ->
      # Create, copy, past a all relatively slow compared to load
      # because of time taken to generate IDs and validate that they
      # are unique to the document. Seems there should be a better
      # solution for that part of the code.
      branch = outline.createItem('branch')

      console.profile('Create Many')
      console.time('Create Many')
      items = []
      for i in [0..10000]
        items.push(outline.createItem('hello'))
      branch.appendChildren(items)
      outline.root.appendChild(branch)
      console.timeEnd('Create Many Items')
      outline.root.descendants.length.should.equal(10008)
      console.profileEnd()

      console.time('Copy Many')
      branch.cloneItem()
      console.timeEnd('Copy Many')

      console.time('Remove Many')
      branch.removeChildren(items)
      console.timeEnd('Remove Many')

    it 'should load 100,000 items', ->
      console.profile('Load Many')
      console.time('Load Many')
      outline = new Outline()
      outline.loadSync(path.join(__dirname, '..', 'fixtures', 'big-outline.ftml'))
      console.timeEnd('Load Many')
      outline.root.descendants.length.should.equal(100007)
      console.profileEnd()
