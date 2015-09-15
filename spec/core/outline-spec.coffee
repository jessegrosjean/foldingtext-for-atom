loadOutlineFixture = require '../load-outline-fixture'
Outline = require '../../lib/core/outline'
shortid = require '../../lib/core/shortid'
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
    oneCopy.bodyString.should.equal('one')
    oneCopy.firstChild.bodyString.should.equal('two')
    oneCopy.firstChild.firstChild.bodyString.should.equal('three')
    oneCopy.firstChild.lastChild.bodyString.should.equal('four')
    oneCopy.lastChild.bodyString.should.equal('five')
    oneCopy.lastChild.firstChild.bodyString.should.equal('six')

  it 'should import item', ->
    outline2 = new Outline()
    oneImport = outline2.importItem(one)
    oneImport.outline.should.equal(outline2)
    oneImport.isInOutline.should.be.false
    oneImport.id.should.equal(one.id)
    oneImport.bodyString.should.equal('one')
    oneImport.firstChild.bodyString.should.equal('two')
    oneImport.firstChild.firstChild.bodyString.should.equal('three')
    oneImport.firstChild.lastChild.bodyString.should.equal('four')
    oneImport.lastChild.bodyString.should.equal('five')
    oneImport.lastChild.firstChild.bodyString.should.equal('six')

  describe 'Insert & Remove Items', ->
    it 'inserts items at indent level 1 by default', ->
      newItem = outline.createItem('new')
      outline.insertItemBefore(newItem, two)
      newItem.depth.should.equal(1)
      newItem.previousSibling.should.equal(one)
      newItem.firstChild.should.equal(two)
      newItem.lastChild.should.equal(five)

    it 'inserts items at specified indent level', ->
      three.indent = 3
      four.indent = 2
      newItem = outline.createItem('new')
      newItem.indent = 3
      outline.insertItemBefore(newItem, three)
      newItem.depth.should.equal(3)
      three.depth.should.equal(5)
      four.depth.should.equal(4)
      two.firstChild.should.equal(newItem)
      newItem.firstChild.should.equal(three)
      newItem.lastChild.should.equal(four)

    it 'inserts items with children', ->
      three.indent = 4
      four.indent = 3
      newItem = outline.createItem('new')
      newItemChild = outline.createItem('new child')
      newItem.appendChild(newItemChild)
      newItem.indent = 3
      outline.insertItemBefore(newItem, three)
      newItem.depth.should.equal(3)
      newItemChild.depth.should.equal(4)
      three.depth.should.equal(6)
      four.depth.should.equal(5)
      two.firstChild.should.equal(newItem)
      newItemChild.firstChild.should.equal(three)
      newItemChild.lastChild.should.equal(four)

    it 'remove item leaving children', ->
      outline.undoManager.beginUndoGrouping()
      outline.removeItem(two)
      outline.undoManager.endUndoGrouping()
      two.isInOutline.should.equal(false)
      three.isInOutline.should.equal(true)
      three.parent.should.equal(one)
      three.depth.should.equal(3)
      four.isInOutline.should.equal(true)
      four.parent.should.equal(one)
      four.depth.should.equal(3)
      outline.undoManager.undo()
      two.isInOutline.should.equal(true)
      two.firstChild.should.equal(three)
      two.lastChild.should.equal(four)
      outline.undoManager.redo()

    it 'should special case remove items', ->
      each.removeFromParent() for each in outline.root.descendants
      one.indent = 1
      two.indent = 3
      three.indent = 2
      four.indent = 1
      outline.insertItemsBefore([one, two, three, four])
      outline.removeItems([one, two])
      root.firstChild.should.equal(three)

    it 'add items in batch in single event', ->

    it 'remove items in batch in single event', ->

  describe 'Undo', ->
    it 'should undo append child', ->
      child = outline.createItem('hello')
      one.appendChild(child)
      outline.undoManager.undo()
      expect(child.parent).toBe(null)

    it 'should undo remove child', ->
      outline.undoManager.beginUndoGrouping()
      one.removeChild(two)
      outline.undoManager.endUndoGrouping()
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
      expect(one.getAttribute('myattr') is undefined).toBe(true)

    describe 'Body Text', ->
      it 'should undo set body text', ->
        one.bodyString = 'hello word'
        outline.undoManager.undo()
        one.bodyString.should.equal('one')

      it 'should undo replace body text', ->
        one.replaceBodyRange(1, 1, 'hello')
        one.bodyString.should.equal('ohelloe')
        outline.undoManager.undo()
        one.bodyString.should.equal('one')

      it 'should coalesce consecutive body text inserts', ->
        one.replaceBodyRange(1, 0, 'a')
        one.replaceBodyRange(2, 0, 'b')
        one.replaceBodyRange(3, 0, 'c')
        one.bodyString.should.equal('oabcne')
        outline.undoManager.undo()
        one.bodyString.should.equal('one')
        outline.undoManager.redo()
        one.bodyString.should.equal('oabcne')

      it 'should coalesce consecutive body text deletes', ->
        one.replaceBodyRange(2, 1, '')
        one.replaceBodyRange(1, 1, '')
        one.replaceBodyRange(0, 1, '')
        one.bodyString.should.equal('')
        outline.undoManager.undo()
        one.bodyString.should.equal('one')
        outline.undoManager.redo()
        one.bodyString.should.equal('')

  describe 'Performance', ->
    it 'should create/copy/remove 10,000 items', ->
      # Create, copy, past a all relatively slow compared to load
      # because of time taken to generate IDs and validate that they
      # are unique to the document. Seems there should be a better
      # solution for that part of the code.
      branch = outline.createItem('branch')

      itemCount = 10000
      console.time('Create Objects')
      items = []
      for i in [0..itemCount]
        items.push(name: shortid())
      console.timeEnd('Create Objects')

      console.profile('Create Items')
      console.time('Create Items')
      items = []
      for i in [0..itemCount]
        items.push(outline.createItem('hello'))
      branch.appendChildren(items)
      outline.root.appendChild(branch)
      console.timeEnd('Create Items')
      outline.root.descendants.length.should.equal(itemCount + 8)
      console.profileEnd()

      console.time('Copy Items')
      branch.cloneItem()
      console.timeEnd('Copy Items')

      console.time('Remove Items')
      branch.removeChildren(items)
      console.timeEnd('Remove Items')

      randoms = []
      for each, i in items
        each.indent = Math.floor(Math.random() * 10)
        #each.indent = randoms[i]
        #randoms.push(each.indent)
      #console.log(randoms.join(', '))

      console.profile('Insert Items')
      console.time('Insert Items')
      outline.insertItemsBefore(items, null)
      console.timeEnd('Insert Items')
      console.profileEnd()

    it 'should load 100,000 items', ->
      console.profile('Load Items')
      console.time('Load Items')
      outline = new Outline()
      outline.loadSync(path.join(__dirname, '..', 'fixtures', 'big-outline.ftml'))
      console.timeEnd('Load Items')
      outline.root.descendants.length.should.equal(100007)
      console.profileEnd()
