loadOutlineFixture = require '../load-outline-fixture'
Editor = require '../../lib/core/outline-editor'

describe 'OutlineEditor', ->
  [outline, root, one, two, three, four, five, six, editor, itemBuffer, itemBufferSubscription, itemBufferDidChangeExpects] = []

  beforeEach ->
    {outline, root, one, two, three, four, five, six} = loadOutlineFixture()
    editor = new Editor(outline)
    itemBuffer = editor.itemBuffer
    itemBufferSubscription = itemBuffer.onDidChange (e) ->
      if itemBufferDidChangeExpects?.length
        exp = itemBufferDidChangeExpects.shift()
        exp(e)

  afterEach ->
    expect(itemBufferDidChangeExpects?.length).toBeFalsy()
    itemBufferDidChangeExpects = null
    itemBufferSubscription.dispose()
    editor.destroy()

  describe 'View', ->

    describe 'Hoisted Item', ->

      it 'should hoist root by default', ->
        expect(editor.getHoistedItem()).toBe(root)
        expect(editor.isVisible(root)).toBeFalsy()

      it 'should make children of hoisted item visible', ->
        editor.setHoistedItem(two)
        expect(editor.isVisible(editor.getHoistedItem())).toBeFalsy()
        expect(editor.isVisible(three)).toBeTruthy()
        expect(editor.isVisible(four)).toBeTruthy()
        expect(itemBuffer.getString()).toBe('three\nfour')

      it 'should hoist item with no children', ->
        editor.setHoistedItem(three)
        expect(itemBuffer.getString()).toBe('')

      it 'should hoist item with no children and insert children when text inserted into buffer', ->
        editor.setHoistedItem(three)
        expect(itemBuffer.getString()).toBe('')
        itemBuffer.replaceRange(0, 0, 'Hello!')
        three.firstChild.bodyString.should.equal('Hello!')

      it 'should not update item index when items are added outide hoisted item', ->
        editor.setHoistedItem(two)
        outline.root.appendChild(outline.createItem('not me!'))
        expect(itemBuffer.getString()).toBe('three\nfour')

    describe 'Expand & Collapse Items', ->

      it 'items should be expanded by default', ->
        expect(itemBuffer.getString()).toEqual('one\ntwo\nthree\nfour\nfive\nsix')
        expect(editor.isExpanded(one)).toBeTruthy()

      it 'should hide children when item is collapsed', ->
        editor.setCollapsed(one)
        expect(editor.isExpanded(one)).toBeFalsy()
        expect(editor.isVisible(two)).toBeFalsy()
        expect(editor.isVisible(five)).toBeFalsy()
        expect(itemBuffer.getString()).toEqual('one')

      it 'should show children when visible item is expanded', ->
        editor.setCollapsed(one)
        editor.setExpanded(one)
        expect(editor.isExpanded(one)).toBeTruthy()
        expect(editor.isVisible(two)).toBeTruthy()
        expect(editor.isVisible(five)).toBeTruthy()
        expect(itemBuffer.getString()).toEqual('one\ntwo\nthree\nfour\nfive\nsix')

      it 'should expand mutliple items at once', ->
        editor.setCollapsed([one, two, five])
        editor.setExpanded([one, two, five])
        expect(itemBuffer.getString()).toEqual('one\ntwo\nthree\nfour\nfive\nsix')

      it 'should expand selected items ', ->
        editor.setCollapsed([two, five])
        editor.setSelectedItemRange(two, 1, five, 2)
        expect(itemBuffer.getString()).toEqual('one\ntwo\nfive')
        editor.setExpanded()
        expect(itemBuffer.getString()).toEqual('one\ntwo\nthree\nfour\nfive\nsix')

    describe 'Filter Items', ->

      it 'should set/get query', ->
        editor.getQuery().should.equal('')
        editor.setQuery('hello world')
        editor.getQuery().should.equal('hello world')

      it 'should filter itemBuffer to show items (and ancestors) matching query', ->
        editor.setQuery('two')
        editor.isVisible(one).should.be.ok()
        editor.isVisible(two).should.be.ok()
        editor.isVisible(three).should.not.be.ok()
        editor.isVisible(five).should.not.be.ok()
        editor.setQuery(null)
        editor.isVisible(one).should.be.ok()
        editor.isVisible(two).should.be.ok()
        editor.isVisible(three).should.be.ok()
        editor.isVisible(five).should.be.ok()

      it 'should expand to show search and restore original expanded after search', ->
        editor.setCollapsed([two, five])
        editor.setQuery('three')
        editor.isVisible(one).should.be.ok()
        editor.isVisible(two).should.be.ok()
        editor.isVisible(three).should.be.ok()
        editor.isVisible(four).should.not.be.ok()
        editor.isVisible(five).should.not.be.ok()
        editor.setQuery('')
        editor.isVisible(one).should.be.ok()
        editor.isVisible(two).should.be.ok()
        editor.isVisible(three).should.not.be.ok()
        editor.isVisible(four).should.not.be.ok()
        editor.isVisible(five).should.be.ok()
        editor.isVisible(six).should.not.be.ok()

      it 'should add new inserted items to search results', ->
        editor.setQuery('three')
        editor.setSelectedItemRange(three, 3)
        editor.insertNewline()
        itemBuffer.getString().should.equal('one\ntwo\nthr\nee')
        editor.setQuery('')
        itemBuffer.getString().should.equal('one\ntwo\nthr\nee\nfour\nfive\nsix')

  describe 'Insert', ->

    it 'should insert new empty item if existing is selected at end', ->
      editor.setSelectedItemRange(two, 3)
      editor.insertNewline()
      editor.getSelectedRange().should.eql(location: 8, length: 0)
      expect(itemBuffer.getString()).toEqual('one\ntwo\n\nthree\nfour\nfive\nsix')

    it 'should insert new split from current if selection is in middle', ->
      editor.setSelectedItemRange(two, 1)
      editor.insertNewline()
      editor.getSelectedRange().should.eql(location: 6, length: 0)
      expect(itemBuffer.getString()).toEqual('one\nt\nwo\nthree\nfour\nfive\nsix')

    it 'should insert empty above current (move current down) if selection at start', ->
      editor.setSelectedItemRange(two, 0)
      editor.insertNewline()
      itemBuffer.getLine(2).item.should.equal(two)
      editor.getSelectedRange().should.eql(location: 5, length: 0)
      expect(itemBuffer.getString()).toEqual('one\n\ntwo\nthree\nfour\nfive\nsix')

  describe 'Serialize', ->

    it 'should serialize range in single item', ->
      editor.serializeRange(0, 1, 'text/plain').should.equal('o')

    it 'should serialize range in single indented item', ->
      editor.serializeRange(5, 1, 'text/plain').should.equal('w')

    it 'should serialize range accross multiple items', ->
      editor.serializeRange(2, 4, 'text/plain').should.equal('e\n\ttw')

    it 'should serialize range accross multiple indented items', ->
      editor.serializeRange(5, 4, 'text/plain').should.equal('wo\n\tt')

    it 'should replace range with items', ->
      serialized = editor.serializeRange(4, 10, 'text/plain')
      deserializedItems = editor.deserializeItems(serialized, 'text/plain')
      editor.replaceRangeWithItems(4, 10, deserializedItems)
      itemBuffer.getString().should.equal('one\ntwo\nthree\nfour\nfive\nsix')
      two.depth.should.equal(2)
      two.firstChild.depth.should.equal(3)
      two.lastChild.depth.should.equal(3)

  describe 'Organize', ->

    describe 'Move Lines', ->

      it 'should move lines up', ->
        editor.setCollapsed(five)
        editor.setSelectedItemRange(five, 1)
        editor.moveLinesUp()
        editor.isExpanded(five).should.be.ok()
        expect(four.parent).toEqual(five)
        expect(six.parent).toEqual(five)
        expect(five.parent).toEqual(one)
        expect(five.previousSibling).toEqual(two)
        editor.getSelectedRange().should.eql(location: 15, length: 0)
        expect(itemBuffer.getString()).toEqual('one\ntwo\nthree\nfive\nfour\nsix')

      it 'should move lines down', ->
        editor.setCollapsed([two])
        editor.setSelectedItemRange(two)
        editor.moveLinesDown()
        expect(six.parent).toEqual(two)
        expect(five.parent).toEqual(one)
        expect(two.previousSibling).toEqual(five)
        editor.getSelectedRange().should.eql(location: 20, length: 0)
        expect(itemBuffer.getString()).toEqual('one\nthree\nfour\nfive\ntwo\nsix')

      it 'should move lines down past hidden items', ->
        editor.setCollapsed([two, five])
        editor.setSelectedItemRange(two)
        editor.moveLinesDown()
        expect(six.parent).toEqual(five)
        expect(five.parent).toEqual(one)
        expect(two.previousSibling).toEqual(five)
        editor.getSelectedRange().should.eql(location: 20, length: 0)
        expect(itemBuffer.getString()).toEqual('one\nthree\nfour\nfive\ntwo')

      it 'should move lines down and expand if capture children', ->
        three.removeFromParent()
        four.removeFromParent()
        editor.setSelectedItemRange(two)
        editor.moveLinesDown()
        six.parent.should.equal(two)
        two.previousSibling.should.equal(five)
        editor.isExpanded(two).should.equal(true)
        editor.getSelectedRange().should.eql(location: 9, length: 0)
        expect(itemBuffer.getString()).toEqual('one\nfive\ntwo\nsix')

      it 'should move lines down without changing indent level', ->
        two.removeFromParent()
        five.removeFromParent()
        root.appendChild(four)
        three.indent = 3
        outline.insertItemBefore(three, four)
        editor.setExpanded(one)
        editor.setSelectedItemRange(one, 1)
        editor.moveLinesDown()
        one.indent.should.equal(1)
        itemBuffer.getString().should.equal('three\none\nfour')

      it 'should move lines right', ->
        editor.setCollapsed(five)
        editor.setSelectedItemRange(five, 1)
        editor.moveLinesRight()
        six.parent.should.equal(two)
        five.parent.should.equal(two)
        five.previousSibling.should.equal(four)
        five.nextSibling.should.equal(six)
        editor.getSelectedRange().should.eql(location: 20, length: 0)
        expect(itemBuffer.getString()).toEqual('one\ntwo\nthree\nfour\nfive\nsix')

      it 'should move lines right special case', ->
        each.removeFromParent() for each in outline.root.descendants
        one.indent = 1
        two.indent = 3
        three.indent = 2
        four.indent = 1
        outline.insertItemsBefore([one, two, three, four])
        editor.setSelectedItemRange(one, 1, two, 1)
        editor.moveLinesRight()
        root.firstChild.should.equal(one)

      it 'should move lines left', ->
        editor.setCollapsed(five)
        editor.setSelectedItemRange(five)
        editor.moveLinesLeft()
        six.parent.should.equal(five)
        six.indent.should.equal(2)
        five.parent.should.equal(root)
        five.previousSibling.should.equal(one)
        editor.getSelectedRange().should.eql(location: 19, length: 0)
        expect(itemBuffer.getString()).toEqual('one\ntwo\nthree\nfour\nfive\nsix')

      it 'should restrict move lines left to hoisted region', ->
        editor.setHoistedItem(two)
        editor.setSelectedItemRange(three, 1)
        editor.moveLinesLeft()
        editor.getSelectedRange().should.eql(location: 1, length: 0)
        expect(itemBuffer.getString()).toEqual('three\nfour')

      it 'should restrict move lines up to hoisted region', ->
        editor.setHoistedItem(two)
        editor.setSelectedItemRange(three, 1)
        editor.moveLinesUp()
        editor.getSelectedRange().should.eql(location: 1, length: 0)
        expect(itemBuffer.getString()).toEqual('three\nfour')

      it 'should restrict move lines down to hoisted region', ->
        editor.setHoistedItem(two)
        editor.setSelectedItemRange(four, 1)
        editor.moveLinesDown()
        editor.getSelectedRange().should.eql(location: 7, length: 0)
        expect(itemBuffer.getString()).toEqual('three\nfour')

    describe 'Move Branches', ->

      it 'should move branches up', ->
        editor.setCollapsed([two, five])
        editor.setSelectedItemRange(five)
        editor.moveBranchesUp()
        one.firstChild.should.equal(five)
        one.lastChild.should.equal(two)
        editor.moveBranchesUp() # should do nothing
        one.firstChild.should.equal(five)

      it 'should move branches down', ->
        editor.setExpanded(one)
        editor.setSelectedItemRange(two)
        editor.moveBranchesDown()
        one.firstChild.should.equal(five)
        one.lastChild.should.equal(two)
        editor.moveBranchesDown() # should do nothing
        one.lastChild.should.equal(two)

      it 'should move items left', ->
        editor.setExpanded(one)
        editor.setSelectedItemRange(two)
        editor.moveBranchesLeft()
        one.firstChild.should.equal(five)
        one.nextSibling.should.equal(two)
        editor.moveBranchesLeft() # should do nothing
        one.nextSibling.should.equal(two)

      it 'should move items left with prev sibling children selected', ->
        editor.setExpanded(one)
        editor.setExpanded(two)
        editor.setSelectedItemRange(four, undefined, five)
        editor.moveBranchesLeft()
        two.nextSibling.should.equal(four)
        four.nextSibling.should.equal(five)

      it 'should move items right', ->
        editor.setExpanded(one)
        editor.setExpanded(two)
        editor.setSelectedItemRange(four)
        editor.moveBranchesRight()
        three.firstChild.should.equal(four)

      it 'should move to same location as current without crash', ->
        editor.moveBranches([one], one.parent, one)

      it 'should move to same location as current without crash', ->
        editor.moveBranches([one], one.parent)

      xit 'should join items', ->
        editor.setExpanded(one)
        editor.setSelectedItemRange(one)
        editor.joinItems()
        one.bodyString.should.equal('one two')
        editor.selection.focusItem.should.equal(one)
        editor.selection.focusOffset.should.equal(3)
        one.firstChild.should.equal(three)
        one.firstChild.nextSibling.should.equal(four)

      xit 'should join items and undo', ->
        editor.setExpanded(one)
        editor.setSelectedItemRange(one)
        editor.joinItems()
        editor.undo()
        two.firstChild.should.equal(three)
        two.lastChild.should.equal(four)

    describe 'Group', ->

      it 'should group selected branches into new branch', ->
        editor.setSelectedItemRange(two, 1, five, 0)
        editor.groupBranches()
        editor.getSelectedRange().should.eql(location: 4, length: 0)
        itemBuffer.getString().should.equal('one\n\ntwo\nthree\nfour\nfive\nsix')

    describe 'Duplicate', ->

      it 'should duplicate selected branches', ->
        editor.setSelectedItemRange(five, 0, five, 2)
        editor.duplicateBranches()
        editor.getSelectedRange().should.eql(location: 28, length: 2)
        expect(itemBuffer.getString()).toEqual('one\ntwo\nthree\nfour\nfive\nsix\nfive\nsix')

    describe 'Promote Children', ->

      it 'should promote child branches', ->
        editor.setSelectedItemRange(two)
        editor.promoteChildBranches()
        editor.getSelectedRange().should.eql(location: 4, length: 0)
        expect(itemBuffer.getString()).toEqual('one\ntwo\nthree\nfour\nfive\nsix')

    describe 'Demote Trailing Siblings', ->

      it 'should demote trailing sibling branches', ->
        editor.setSelectedItemRange(two)
        editor.demoteTrailingSiblingBranches()
        editor.getSelectedRange().should.eql(location: 4, length: 0)
        expect(itemBuffer.getString()).toEqual('one\ntwo\nthree\nfour\nfive\nsix')