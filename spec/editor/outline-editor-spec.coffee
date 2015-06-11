loadOutlineFixture = require '../load-outline-fixture'
OutlineEditor = require '../../lib/editor/outline-editor'
Outline = require '../../lib/core/outline'

describe 'OutlineEditor', ->
  [jasmineContent, editor, outline, root, one, two, three, four, five, six] = []

  beforeEach ->
    {outline, root, one, two, three, four, five, six} = loadOutlineFixture()
    jasmineContent = document.body.querySelector('#jasmine-content')
    editor = new OutlineEditor(outline)
    jasmineContent.appendChild editor.outlineEditorElement

  afterEach ->
    editor.destroy()

  describe 'Hoisting', ->
    it 'should hoist root by default', ->
      editor.getHoistedItem().should.equal(outline.root)
      editor.isVisible(editor.getHoistedItem()).should.be.false

    it 'should make children of hoisted item visible', ->
      editor.hoistItem(two)
      editor.isVisible(editor.getHoistedItem()).should.be.false
      editor.isVisible(three).should.be.true
      editor.isVisible(four).should.be.true

    describe 'Auto Create Child', ->
      it 'should autocreate child when needed', ->
        expect(three.firstChild).toBe(undefined)
        editor.hoistItem(three)
        three.firstChild.should.be.ok

      it 'should select autocreated child', ->
        editor.hoistItem(three)
        editor.isSelected(three.firstChild).should.be.true

      it 'should delete autocreated child if empty', ->
        editor.hoistItem(three)
        editor.unhoist()
        expect(three.firstChild).toBe(undefined)

      it 'should not delete autocreated child if not empty', ->
        editor.hoistItem(three)
        three.firstChild.bodyText = 'save me!'
        editor.unhoist()
        three.firstChild.should.be.ok

  describe 'Expanding', ->
    it 'should make children of expanded visible', ->
      editor.setExpanded(one)
      editor.isExpanded(one).should.be.true
      editor.isVisible(two).should.be.true
      editor.isVisible(five).should.be.true

      editor.setCollapsed(one)
      editor.isExpanded(one).should.be.false
      editor.isVisible(two).should.be.false
      editor.isVisible(five).should.be.false

    it 'should toggle expanded state', ->
      editor.toggleFoldItems(one)
      editor.isExpanded(one).should.be.true

      editor.toggleFoldItems(one)
      editor.isExpanded(one).should.be.false

  describe 'Visibility', ->
    it 'should know if item is visible', ->
      editor.isVisible(one).should.be.ok
      editor.isVisible(two).should.not.be.ok
      editor.isVisible(three).should.not.be.ok
      editor.isVisible(five).should.not.be.ok

  describe 'Search', ->
    it 'should set search', ->
      editor.setSearch('//li/p[text()=\'two\']', OutlineEditor.X_PATH_SEARCH)
      editor.isVisible(one).should.be.ok
      editor.isVisible(two).should.be.ok
      editor.isVisible(three).should.not.be.ok
      editor.isVisible(five).should.not.be.ok
      editor.setSearch(null)
      editor.isVisible(one).should.be.ok
      editor.isVisible(two).should.not.be.ok
      editor.isVisible(three).should.not.be.ok
      editor.isVisible(five).should.not.be.ok

    it 'should restore expanded/collapse state after search', ->
      editor.setExpanded(one)
      editor.setSearch('three')
      editor.isVisible(one).should.be.ok
      editor.isVisible(two).should.be.ok
      editor.isVisible(three).should.be.ok
      editor.isVisible(four).should.not.be.ok
      editor.isVisible(five).should.not.be.ok
      editor.setSearch('')
      editor.isVisible(one).should.be.ok
      editor.isVisible(two).should.be.ok
      editor.isVisible(three).should.not.be.ok
      editor.isVisible(four).should.not.be.ok
      editor.isVisible(five).should.be.ok
      editor.isVisible(six).should.not.be.ok

  describe 'Selection', ->
    it 'should select item', ->
      editor.moveSelectionRange(one)
      editor.selection.items.should.eql([one])
      editor.selection.isOutlineMode.should.be.true
      editor.selection.focusItem.should.equal(one)
      editor.selection.anchorItem.should.equal(one)
      expect(editor.selection.focusOffset is undefined).toBe(true)
      expect(editor.selection.anchorOffset is undefined).toBe(true)

    it 'should select item text', ->
      editor.moveSelectionRange(one, 1)
      editor.selection.items.should.eql([one])
      editor.selection.isTextMode.should.be.true

    it 'should extend text selection', ->
      editor.moveSelectionRange(one, 1)
      editor.extendSelectionRange(one, 3)
      editor.selection.isTextMode.should.be.true
      editor.selection.focusOffset.should.equal(3)
      editor.selection.anchorOffset.should.equal(1)

    it 'should null/undefined selection if invalid', ->
      editor.moveSelectionRange(one, 4)
      editor.selection.isValid.should.be.false
      expect(editor.selection.focusItem is null).toBe(true)
      expect(editor.selection.focusOffset is undefined).toBe(true)

  describe 'Formatting', ->
    it 'should toggle formatting', ->
      editor.moveSelectionRange(one, 0, one, 2)
      editor.toggleFormattingTag('B')
      one.bodyHTML.should.equal('<b>on</b>e')
      editor.toggleFormattingTag('B')
      one.bodyHTML.should.equal('one')

    it 'should toggle typing formatting tags if collapsed selection', ->
      one.bodyText = ''
      editor.moveSelectionRange(one, 0)
      editor.toggleFormattingTag('B')
      editor.insertText('hello')
      one.bodyHTML.should.equal('<b>hello</b>')
      editor.toggleFormattingTag('B')
      editor.insertText('world')
      one.bodyHTML.should.equal('<b>hello</b>world')

    describe 'Items', ->
      describe 'Moving', ->
        it 'should move items up', ->
          editor.setExpanded(one)
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

        it 'should move items left by adjusting indent if they are over-indent', ->
          editor.setExpanded(one)
          editor.moveSelectionRange(two)
          editor.moveItemsRight() # over-indent
          editor.moveItemsRight() # over-indent
          two.indent.should.equal(3)
          editor.moveItemsLeft()
          two.indent.should.equal(2)
          editor.moveItemsLeft()
          two.indent.should.equal(1)

        it 'should move items right', ->
          editor.setExpanded(one)
          editor.setExpanded(two)
          editor.moveSelectionRange(four)
          editor.moveItemsRight()
          three.firstChild.should.equal(four)
          four.indent.should.equal(1)
          editor.moveItemsRight() # should over-indent
          four.indent.should.equal(2)
          editor.moveItemsRight() # should over-indent
          four.indent.should.equal(3)
          three.firstChild.should.equal(four)

      describe 'Deleting', ->
        it 'should delete selection', ->
          editor.moveSelectionRange(one, 1, one, 3)
          editor.delete()
          one.bodyText.should.equal('o')

        it 'should delete backward by character', ->
          editor.moveSelectionRange(one, 1)
          editor.delete('backward', 'character')
          one.bodyText.should.equal('ne')

        it 'should delete forward by character', ->
          editor.moveSelectionRange(one, 1)
          editor.delete('forward', 'character')
          one.bodyText.should.equal('oe')

        it 'should delete backward by word', ->
          one.bodyText = 'one two three'
          editor.moveSelectionRange(one, 7)
          editor.delete('backward', 'word')
          one.bodyText.should.equal('one  three')

        it 'should delete forward by word', ->
          one.bodyText = 'one two three'
          editor.moveSelectionRange(one, 7)
          editor.delete('forward', 'word')
          one.bodyText.should.equal('one two')

        it 'should delete backward by line boundary', ->
          one.bodyText = 'one two three'
          editor.moveSelectionRange(one, 12)
          editor.delete('backward', 'lineboundary')
          one.bodyText.should.equal('e')

        it 'should delete backward by character joining with previous node', ->
          editor.setExpanded(one)
          editor.moveSelectionRange(two, 0)
          editor.delete('backward', 'character')
          one.bodyText.should.equal('onetwo')
          editor.selection.focusItem.should.eql(one)
          editor.selection.focusOffset.should.eql(3)
          two.isInOutline.should.be.false
          three.isInOutline.should.be.true
          three.parent.should.eql(one)
          four.isInOutline.should.be.true
          four.parent.should.eql(one)

        it 'should delete backward by word joining with previous node', ->
          editor.setExpanded(one)
          editor.moveSelectionRange(two, 0)
          editor.delete('backward', 'word')
          one.bodyText.should.equal('two')
          editor.selection.focusItem.should.eql(one)
          editor.selection.focusOffset.should.eql(0)
          two.isInOutline.should.be.false

        it 'should delete backward by word from empty line joining with previous node', ->
          editor.setExpanded(one)
          two.bodyText = ''
          editor.moveSelectionRange(two, 0)
          editor.delete('backward', 'word')
          one.bodyText.should.equal('')
          editor.selection.focusItem.should.eql(one)
          editor.selection.focusOffset.should.eql(0)
          two.isInOutline.should.be.false

        it 'should delete forward by character joining with next node', ->
          editor.setExpanded(one)
          editor.moveSelectionRange(one, 3)
          editor.delete('forward', 'character')
          one.bodyText.should.equal('onetwo')
          editor.selection.focusItem.should.eql(one)
          editor.selection.focusOffset.should.eql(3)
          two.isInOutline.should.be.false

        it 'should delete forward by word joining with previous node', ->
          editor.setExpanded(one)
          editor.moveSelectionRange(one, 3)
          editor.delete('forward', 'word')
          one.bodyText.should.equal('one')
          editor.selection.focusItem.should.eql(one)
          editor.selection.focusOffset.should.eql(3)
          two.isInOutline.should.be.false

    describe 'Lines', ->
      describe 'Moving', ->
        it 'should move lines up', ->
          editor.setExpanded(one)
          editor.setExpanded(two)
          editor.moveSelectionRange(five)
          editor.moveLinesUp()
          six.parent.should.equal(five)
          five.parent.should.equal(one)
          five.previousSibling.should.equal(two)

        it 'should move lines down', ->
          editor.setExpanded(one)
          editor.moveSelectionRange(five)
          editor.moveLinesDown()
          six.parent.should.equal(two)
          five.parent.should.equal(one)
          five.previousSibling.should.equal(two)

        it 'should move lines right', ->
          editor.setExpanded(one)
          editor.setExpanded(two)
          editor.moveSelectionRange(five)
          editor.moveLinesRight()
          six.parent.should.equal(two)
          five.parent.should.equal(two)
          five.previousSibling.should.equal(four)
          five.nextSibling.should.equal(six)

        it 'should move lines left', ->
          editor.setExpanded(one)
          editor.setExpanded(two)
          editor.moveSelectionRange(five)
          editor.moveLinesLeft()
          six.parent.should.equal(five)
          six.indent.should.equal(2)
          five.parent.should.equal(root)
          five.previousSibling.should.equal(one)

      describe 'Deleting', ->
        it 'should delete lines and reparent children to previous sibling', ->
          editor.setExpanded(one)
          editor.moveSelectionRange(five)
          editor.deleteParagraphsBackward()
          six.parent.should.equal(two)
          six.indent.should.equal(1)

        it 'should delete lines and reparent children to parent if no previous sibling', ->
          editor.setExpanded(one)
          editor.moveSelectionRange(two)
          editor.deleteParagraphsBackward()
          three.parent.should.equal(one)
          three.indent.should.equal(2)
          four.parent.should.equal(one)
          four.indent.should.equal(2)

  describe 'Focus', ->
    it 'should not focus editor when setting selection unless it already has focus', ->
      editor.moveSelectionRange(one)
      document.activeElement.should.not.equal(editor.outlineEditorElement.focusElement)
      editor.moveSelectionRange(one, 1)
      document.activeElement.textContent.should.not.equal(one.bodyText)

    it 'should focus item mode focus element when selecting item', ->
      editor.focus()
      editor.moveSelectionRange(one)
      document.activeElement.should.equal(editor.outlineEditorElement.focusElement)
      editor.moveSelectionRange(one, 1)
      document.activeElement.textContent.should.equal(one.bodyText)

    it 'should focus item text when selecting item text', ->
      editor.focus()
      editor.moveSelectionRange(one, 1)
      document.getSelection().focusNode.should.equal(editor.outlineEditorElement.renderedBodyTextSPANForItem(one).firstChild)
      document.getSelection().focusOffset.should.equal(1)
      document.activeElement.textContent.should.equal(one.bodyText)

    it 'should focus item text when extending text selection', ->
      editor.focus()
      editor.moveSelectionRange(one, 1)
      editor.extendSelectionRange(one, 3)
      document.getSelection().focusNode.should.equal(editor.outlineEditorElement.renderedBodyTextSPANForItem(one).firstChild)
      document.getSelection().focusOffset.should.equal(3)
      document.getSelection().anchorOffset.should.equal(1)

    it 'should focus item mode focus element when extending to item selection', ->
      editor.focus()
      editor.setExpanded(one)
      editor.moveSelectionRange(two, 1)
      editor.extendSelectionRange(five, 3)
      document.activeElement.should.equal(editor.outlineEditorElement.focusElement)

    it 'should focus item mode focus element on invalid selection', ->
      editor.focus()
      editor.moveSelectionRange(one, 4)
      document.activeElement.should.equal(editor.outlineEditorElement.focusElement)

  describe 'Copy Path to Clipboard', ->
    it 'should copy path query parameters even when outline has no path', ->
      editor.copyPathToClipboard()
      atom.clipboard.read().should.equal('file://?selection=1%2C0%2C1%2C0')

      editor.setSearch('one two')
      editor.copyPathToClipboard()
      atom.clipboard.read().should.equal('file://?query=one%20two')