OutlineEditor = require '../../lib/text/outline/outline-editor'
loadOutlineFixture = require '../load-outline-fixture'

describe 'OutlineEditor', ->
  [outline, root, one, two, three, four, five, six, editor, buffer, bufferSubscription, bufferDidChangeExpects] = []

  beforeEach ->
    {outline, root, one, two, three, four, five, six} = loadOutlineFixture()

    editor = new OutlineEditor(outline)
    buffer = editor.outlineBuffer
    bufferSubscription = buffer.onDidChange (e) ->
      if bufferDidChangeExpects?.length
        exp = bufferDidChangeExpects.shift()
        exp(e)

  afterEach ->
    expect(bufferDidChangeExpects?.length).toBeFalsy()
    bufferDidChangeExpects = null
    bufferSubscription.dispose()
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
        expect(buffer.getText()).toBe('three\nfour')

      it 'should hoist item with no children', ->
        editor.setHoistedItem(three)
        expect(buffer.getText()).toBe('')

      it 'should not update buffer when items are added outide hoisted item', ->
        editor.setHoistedItem(two)
        outline.root.appendChild(outline.createItem('not me!'))
        expect(buffer.getText()).toBe('three\nfour')

    describe 'Expand & Collapse Items', ->

      it 'items should be expanded by default', ->
        expect(buffer.getText()).toEqual('one\n\ttwo\n\t\tthree\n\t\tfour\n\tfive\n\t\tsix')
        expect(editor.isExpanded(one)).toBeTruthy()

      it 'should hide children when item is collapsed', ->
        editor.setCollapsed(one)
        expect(editor.isExpanded(one)).toBeFalsy()
        expect(editor.isVisible(two)).toBeFalsy()
        expect(editor.isVisible(five)).toBeFalsy()
        expect(buffer.getText()).toEqual('one')

      it 'should show children when visible item is expanded', ->
        editor.setCollapsed(one)
        editor.setExpanded(one)
        expect(editor.isExpanded(one)).toBeTruthy()
        expect(editor.isVisible(two)).toBeTruthy()
        expect(editor.isVisible(five)).toBeTruthy()
        expect(buffer.getText()).toEqual('one\n\ttwo\n\t\tthree\n\t\tfour\n\tfive\n\t\tsix')

      it 'should expand mutliple items at once', ->
        editor.setCollapsed([one, two, five])
        editor.setExpanded([one, two, five])
        expect(buffer.getText()).toEqual('one\n\ttwo\n\t\tthree\n\t\tfour\n\tfive\n\t\tsix')

      it 'should expand selected items ', ->
        editor.setCollapsed([two, five])
        editor.setSelectedItemRange(two, 1, five, 2)
        expect(buffer.getText()).toEqual('one\n\ttwo\n\tfive')
        editor.setExpanded()
        expect(buffer.getText()).toEqual('one\n\ttwo\n\t\tthree\n\t\tfour\n\tfive\n\t\tsix')

  describe 'Insert', ->

    it 'should insert new empty item if existing is selected at end', ->
      editor.setSelectedItemRange(two, 4)
      editor.insertNewline()
      editor.getSelectedRange().toString().should.equal('[(2, 2) - (2, 2)]')
      expect(buffer.getText()).toEqual('one\n\ttwo\n\t\t\n\t\tthree\n\t\tfour\n\tfive\n\t\tsix')

    it 'should insert new split from current if selection is in middle', ->
      editor.setSelectedItemRange(two, 2)
      editor.insertNewline()
      editor.getSelectedRange().toString().should.equal('[(2, 2) - (2, 2)]')
      expect(buffer.getText()).toEqual('one\n\tt\n\t\two\n\t\tthree\n\t\tfour\n\tfive\n\t\tsix')

    it 'should insert empty above current (move current down) if selection at start', ->
      editor.setSelectedItemRange(two, 1)
      editor.insertNewline()
      buffer.getLine(2).item.should.equal(two)
      editor.getSelectedRange().toString().should.equal('[(2, 1) - (2, 1)]')
      expect(buffer.getText()).toEqual('one\n\t\n\ttwo\n\t\tthree\n\t\tfour\n\tfive\n\t\tsix')

  describe 'Organize', ->

    describe 'Move Lines', ->
      it 'should move lines up', ->
        editor.setCollapsed(five)
        editor.setSelectedItemRange(five, 1)
        editor.moveLinesUp()
        expect(editor.isExpanded(five)).toBeTruthy()
        expect(four.parent).toEqual(five)
        expect(six.parent).toEqual(five)
        expect(five.parent).toEqual(one)
        expect(five.previousSibling).toEqual(two)
        expect(editor.getSelectedRange().toString()).toEqual('[(3, 1) - (3, 1)]')
        expect(buffer.getText()).toEqual('one\n\ttwo\n\t\tthree\n\tfive\n\t\tfour\n\t\tsix')

      it 'should move lines down', ->
        editor.setCollapsed([two, five])
        editor.setSelectedItemRange(two)
        editor.moveLinesDown()
        expect(six.parent).toEqual(two)
        expect(five.parent).toEqual(one)
        expect(two.previousSibling).toEqual(five)
        expect(editor.getSelectedRange().toString()).toEqual('[(4, 0) - (4, 0)]')
        expect(buffer.getText()).toEqual('one\n\t\tthree\n\t\tfour\n\tfive\n\ttwo\n\t\tsix')

      it 'should move lines down and expand if capture children', ->
        three.removeFromParent()
        four.removeFromParent()
        editor.setSelectedItemRange(two)
        editor.moveLinesDown()
        six.parent.should.equal(two)
        two.previousSibling.should.equal(five)
        editor.isExpanded(two).should.equal(true)
        expect(editor.getSelectedRange().toString()).toEqual('[(2, 0) - (2, 0)]')
        expect(buffer.getText()).toEqual('one\n\tfive\n\ttwo\n\t\tsix')

      it 'should move lines down without changing indent level', ->
        two.removeFromParent()
        five.removeFromParent()
        root.appendChild(four)
        three.indent = 3
        outline.insertItemBefore(three, four)
        editor.setSelectedItemRange(one, 1)
        editor.moveLinesDown()
        one.indent.should.equal(1)
        buffer.getText().should.equal('\t\tthree\none\nfour')

      it 'should move lines right', ->
        editor.setCollapsed(five)
        editor.setSelectedItemRange(five, 1)
        editor.moveLinesRight()
        six.parent.should.equal(two)
        five.parent.should.equal(two)
        five.previousSibling.should.equal(four)
        five.nextSibling.should.equal(six)
        expect(editor.getSelectedRange().toString()).toEqual('[(4, 2) - (4, 2)]')
        expect(buffer.getText()).toEqual('one\n\ttwo\n\t\tthree\n\t\tfour\n\t\tfive\n\t\tsix')

      it 'should move lines left', ->
        editor.setCollapsed(five)
        editor.setSelectedItemRange(five)
        editor.moveLinesLeft()
        six.parent.should.equal(five)
        six.indent.should.equal(2)
        five.parent.should.equal(root)
        five.previousSibling.should.equal(one)
        expect(editor.getSelectedRange().toString()).toEqual('[(4, 0) - (4, 0)]')
        expect(buffer.getText()).toEqual('one\n\ttwo\n\t\tthree\n\t\tfour\nfive\n\t\tsix')

      it 'should restrict move lines left to hoisted region', ->
        editor.setHoistedItem(two)
        editor.setSelectedItemRange(three, 1)
        editor.moveLinesLeft()
        expect(editor.getSelectedRange().toString()).toEqual('[(0, 1) - (0, 1)]')
        expect(buffer.getText()).toEqual('three\nfour')

      it 'should restrict move lines up to hoisted region', ->
        editor.setHoistedItem(two)
        editor.setSelectedItemRange(three, 1)
        editor.moveLinesUp()
        expect(editor.getSelectedRange().toString()).toEqual('[(0, 1) - (0, 1)]')
        expect(buffer.getText()).toEqual('three\nfour')

      it 'should restrict move lines down to hoisted region', ->
        editor.setHoistedItem(two)
        editor.setSelectedItemRange(four, 1)
        editor.moveLinesDown()
        expect(editor.getSelectedRange().toString()).toEqual('[(1, 1) - (1, 1)]')
        expect(buffer.getText()).toEqual('three\nfour')

    xdescribe 'Move Branches', ->
      it 'should move items up', ->
        editor.setCollapsed([two, five])
        editor.moveSelectionRange(five)
        editor.moveItemsUp()
        one.firstChild.should.equal(five)
        one.lastChild.should.equal(two)
        editor.moveItemsUp() # should do nothing
        one.firstChild.should.equal(five)

      it 'should move items down', ->
        editor.setExpanded(one)
        editor.moveSelectionRange(two)
        editor.moveItemsDown()
        one.firstChild.should.equal(five)
        one.lastChild.should.equal(two)
        editor.moveItemsDown() # should do nothing
        one.lastChild.should.equal(two)

      it 'should move items left', ->
        editor.setExpanded(one)
        editor.moveSelectionRange(two)
        editor.moveItemsLeft()
        one.firstChild.should.equal(five)
        one.nextSibling.should.equal(two)
        editor.moveItemsLeft() # should do nothing
        one.nextSibling.should.equal(two)

      it 'should move items left with prev sibling children selected', ->
        editor.setExpanded(one)
        editor.setExpanded(two)
        editor.moveSelectionRange(four, undefined, five)
        editor.moveItemsLeft()
        two.nextSibling.should.equal(four)
        four.nextSibling.should.equal(five)

      it 'should move items right', ->
        editor.setExpanded(one)
        editor.setExpanded(two)
        editor.moveSelectionRange(four)
        editor.moveItemsRight()
        three.firstChild.should.equal(four)

      it 'should duplicate items', ->
        editor.setExpanded(one)
        editor.setExpanded(two)
        editor.moveSelectionRange(two)
        editor.duplicateItems()
        editor.selection.focusItem.should.equal(two.nextSibling)
        editor.isExpanded(two.nextSibling).should.be.ok
        two.nextSibling.bodyText.should.equal('two')
        two.nextSibling.firstChild.bodyText.should.equal('three')

      it 'should join items', ->
        editor.setExpanded(one)
        editor.moveSelectionRange(one)
        editor.joinItems()
        one.bodyText.should.equal('one two')
        editor.selection.focusItem.should.equal(one)
        editor.selection.focusOffset.should.equal(3)
        one.firstChild.should.equal(three)
        one.firstChild.nextSibling.should.equal(four)

      it 'should join items and undo', ->
        editor.setExpanded(one)
        editor.moveSelectionRange(one)
        editor.joinItems()
        editor.undo()
        two.firstChild.should.equal(three)
        two.lastChild.should.equal(four)

    describe 'Group', ->

      it 'should group selected branches into new branch', ->
        editor.setSelectedItemRange(two, 1, five, 0)
        editor.groupBranches()
        editor.getSelectedRange().toString().should.equal('[(1, 1) - (1, 1)]')
        buffer.getText().should.equal('one\n\t\n\t\ttwo\n\t\t\tthree\n\t\t\tfour\n\t\tfive\n\t\t\tsix')

    describe 'Duplicate', ->

      it 'should duplicate selected branches', ->
        editor.setSelectedItemRange(five, 0, five, 2)
        editor.duplicateBranches()
        editor.getSelectedRange().toString().should.equal('[(6, 0) - (6, 2)]')
        expect(buffer.getText()).toEqual('one\n\ttwo\n\t\tthree\n\t\tfour\n\tfive\n\t\tsix\n\tfive\n\t\tsix')

    describe 'Promote Children', ->

      it 'should promote child branches', ->
        editor.setSelectedItemRange(two)
        editor.promoteChildBranches()
        editor.getSelectedRange().toString().should.equal('[(1, 0) - (1, 0)]')
        expect(buffer.getText()).toEqual('one\n\ttwo\n\tthree\n\tfour\n\tfive\n\t\tsix')

    describe 'Demote Trailing Siblings', ->

      it 'should demote trailing sibling branches', ->
        editor.setSelectedItemRange(two)
        editor.demoteTrailingSiblingBranches()
        editor.getSelectedRange().toString().should.equal('[(1, 0) - (1, 0)]')
        expect(buffer.getText()).toEqual('one\n\ttwo\n\t\tthree\n\t\tfour\n\t\tfive\n\t\t\tsix')