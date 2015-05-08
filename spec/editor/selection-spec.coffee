loadOutlineFixture = require '../load-outline-fixture'
OutlineEditor = require '../../lib/editor/outline-editor'
Selection = require '../../lib/editor/selection'
Outline = require '../../lib/core/outline'

describe 'Selection', ->
  [jasmineContent, editor, outline, root, one, two, three, four, five, six] = []

  beforeEach ->
    {outline, root, one, two, three, four, five, six} = loadOutlineFixture()
    jasmineContent = document.body.querySelector('#jasmine-content')
    editor = new OutlineEditor(outline)
    jasmineContent.appendChild editor.outlineEditorElement
    editor.outlineEditorElement.disableAnimation() # otherwise breaks geometry tests sometimes
    editor.setExpanded [one, five]

  afterEach ->
    editor.destroy()

  describe 'Modify', ->
    describe 'Character', ->
      it 'should move/backward/character', ->
        r = editor.createSelection(six, 1)
        r = r.selectionByModifying('move', 'backward', 'character')
        r.focusItem.should.equal(six)
        r.focusOffset.should.equal(0)

        r = r.selectionByModifying('move', 'backward', 'character')
        r.focusItem.should.equal(five)
        r.focusOffset.should.equal(4)

      it 'should move/forward/character', ->
        r = editor.createSelection(one, 2)
        r = r.selectionByModifying('move', 'forward', 'character')
        r.focusItem.should.equal(one)
        r.focusOffset.should.equal(3)

        r = r.selectionByModifying('move', 'forward', 'character')
        r.focusItem.should.equal(two)
        r.focusOffset.should.equal(0)

    describe 'Word', ->
      it 'should move/backward/word', ->
        six.bodyText = 'one two'
        r = editor.createSelection(six, 5)

        r = r.selectionByModifying('move', 'backward', 'word')
        r.focusItem.should.equal(six)
        r.focusOffset.should.equal(4)

        r = r.selectionByModifying('move', 'backward', 'word')
        r.focusItem.should.equal(six)
        r.focusOffset.should.equal(0)

        r = r.selectionByModifying('move', 'backward', 'word')
        r.focusItem.should.equal(five)
        r.focusOffset.should.equal(0)

      it 'should move/forward/word', ->
        one.bodyText = 'one two'
        r = editor.createSelection(one, 1)

        r = r.selectionByModifying('move', 'forward', 'word')
        r.focusItem.should.equal(one)
        r.focusOffset.should.equal(3)

        r = r.selectionByModifying('move', 'forward', 'word')
        r.focusItem.should.equal(one)
        r.focusOffset.should.equal(7)

        r = r.selectionByModifying('move', 'forward', 'word')
        r.focusItem.should.equal(two)
        r.focusOffset.should.equal(3)

      it 'should move/forward/word japanese', ->
        one.bodyText = 'ジェッセワsヘレ'
        r = editor.createSelection(one, 0)

        r = r.selectionByModifying('move', 'forward', 'word')
        r.focusItem.should.equal(one)
        r.focusOffset.should.equal(5)

        r = r.selectionByModifying('move', 'forward', 'word')
        r.focusItem.should.equal(one)
        r.focusOffset.should.equal(6)

        r = r.selectionByModifying('move', 'forward', 'word')
        r.focusItem.should.equal(one)
        r.focusOffset.should.equal(8)

        r = r.selectionByModifying('move', 'forward', 'word')
        r.focusItem.should.equal(two)
        r.focusOffset.should.equal(3)

    describe 'Sentence', ->
      it 'should move/backward/sentance', ->
        six.bodyText = 'Hello world! Let\'s take a look at this.'
        r = editor.createSelection(six, 26)

        r = r.selectionByModifying('move', 'backward', 'sentence')
        r.focusItem.should.equal(six)
        r.focusOffset.should.equal(13)

        r = r.selectionByModifying('move', 'backward', 'sentence')
        r.focusItem.should.equal(six)
        r.focusOffset.should.equal(0)

        r = r.selectionByModifying('move', 'backward', 'sentence')
        r.focusItem.should.equal(five)
        r.focusOffset.should.equal(0)

      it 'should move/forward/sentence', ->
        one.bodyText = 'Hello world! Let\'s take a look at this.'
        r = editor.createSelection(one, 8)

        r = r.selectionByModifying('move', 'forward', 'sentence')
        r.focusItem.should.equal(one)
        r.focusOffset.should.equal(13)

        r = r.selectionByModifying('move', 'forward', 'sentence')
        r.focusItem.should.equal(one)
        r.focusOffset.should.equal(39)

        r = r.selectionByModifying('move', 'forward', 'sentence')
        r.focusItem.should.equal(two)
        r.focusOffset.should.equal(3)

    describe 'Line Boundary', ->
      it 'should move/backward/lineboundary', ->
        r = editor.createSelection(two, 1)
        r = r.selectionByModifying('move', 'backward', 'lineboundary')
        r.focusItem.should.equal(two)
        r.focusOffset.should.equal(0)

      it 'should move/forward/lineboundary', ->
        r = editor.createSelection(two, 1)
        r = r.selectionByModifying('move', 'forward', 'lineboundary')
        r.focusItem.should.equal(two)
        r.focusOffset.should.equal(3)

    describe 'Line', ->
      it 'should move/backward/line', ->
        editor.moveSelectionRange(six, 0)
        r = editor.selection
        r = r.selectionByModifying('move', 'backward', 'line')
        r.focusItem.should.equal(five)
        r.focusOffset.should.equal(4)

      it 'should move/forward/line', ->
        editor.moveSelectionRange(five, 0)
        r = editor.selection
        r = r.selectionByModifying('move', 'forward', 'line')
        r.focusItem.should.equal(six)
        r.focusOffset.should.equal(0)

    describe 'Paragraph Boundary', ->
      it 'should move/backward/paragraphboundary', ->
        r = editor.createSelection(six, 3)
        r = r.selectionByModifying('move', 'backward', 'paragraphboundary')
        r.focusItem.should.equal(six)
        r.focusOffset.should.equal(0)

        r = r.selectionByModifying('move', 'backward', 'paragraphboundary')
        r.focusItem.should.equal(six)
        r.focusOffset.should.equal(0)

      it 'should move/forward/paragraphboundary', ->
        r = editor.createSelection(one, 0)
        r = r.selectionByModifying('move', 'forward', 'paragraphboundary')
        r.focusItem.should.equal(one)
        r.focusOffset.should.equal(3)

        r = r.selectionByModifying('move', 'forward', 'paragraphboundary')
        r.focusItem.should.equal(one)
        r.focusOffset.should.equal(3)

    describe 'Paragraph', ->
      it 'should move/backward/paragraph', ->
        r = editor.createSelection(six, 3)
        r = r.selectionByModifying('move', 'backward', 'paragraph')
        r.focusItem.should.equal(five)
        r.focusOffset.should.equal(0)

        r = r.selectionByModifying('move', 'backward', 'paragraph')
        r.focusItem.should.equal(two)
        r.focusOffset.should.equal(0)

      it 'should move/forward/paragraph', ->
        r = editor.createSelection(one, 2)
        r = r.selectionByModifying('move', 'forward', 'paragraph')
        r.focusItem.should.equal(two)
        r.focusOffset.should.equal(3)

        r = r.selectionByModifying('move', 'forward', 'paragraph')
        r.focusItem.should.equal(five)
        r.focusOffset.should.equal(4)

  describe 'Geometry', ->
    it 'should get client rects from selection', ->
      itemRect = editor.createSelection(one).focusClientRect
      textRect1 = editor.createSelection(one, 0).focusClientRect
      textRect2 = editor.createSelection(one, 3).focusClientRect

      expect(textRect1.left >= itemRect.left).toBe(true)
      expect(textRect1.top >= itemRect.top).toBe(true)
      expect(textRect1.bottom <= itemRect.bottom).toBe(true)
      textRect1.left.should.be.lessThan(textRect2.left)

    it 'should get client rects from empty selection', ->
      one.bodyText = ''

      charRect = editor.createSelection(one, 0).focusClientRect
      itemRect = editor.createSelection(one).focusClientRect

      itemRect.left.should.equal(charRect.left)
      charRect.width.should.equal(0)