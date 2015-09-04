loadOutlineFixture = require '../load-outline-fixture'
OutlineEditor = require '../../lib/editor/outline-editor'
AttributedString = require '../../lib/core/attributed-string'
ItemRenderer = require '../../lib/editor/item-renderer'
Outline = require '../../lib/core/outline'

describe 'OutlineEditorElement', ->
  [jasmineContent, editorElement, editor, outline, root, one, two, three, four, five, six] = []

  beforeEach ->
    {outline, root, one, two, three, four, five, six} = loadOutlineFixture()
    jasmineContent = document.body.querySelector('#jasmine-content')
    editor = new OutlineEditor(outline)
    editorElement = editor.outlineEditorElement
    jasmineContent.appendChild editorElement
    editor.outlineEditorElement.disableAnimation() # otherwise breaks geometry tests sometimes
    editor.setExpanded [one, two, five]

  afterEach ->
    editor.destroy()

  describe 'Render', ->
    describe 'Model', ->
      it 'should render outline', ->
        editorElement.textContent.should.equal('onetwothreefourfivesix')

      it 'should update when text changes', ->
        three.bodyText = 'NEW'
        editorElement.textContent.should.equal('onetwoNEWfourfivesix')

      it 'should update when child is added', ->
        two.appendChild(outline.createItem('Howdy!'))
        editorElement.textContent.should.equal('onetwothreefourHowdy!fivesix')

      it 'should update when child is removed', ->
        editorElement.disableAnimation()
        two.removeFromParent()
        editorElement.enableAnimation()
        editorElement.textContent.should.equal('onefivesix')

      it 'should update when attribute is changed', ->
        viewLI = document.getElementById(three.id)
        expect(viewLI.getAttribute('my')).toBe(null)
        three.setAttribute('my', 'test')
        viewLI.getAttribute('my').should.equal('test')

      it 'should update when body text is changed', ->
        viewLI = document.getElementById(one.id)
        one.bodyText = 'one two three'
        one.addBodyTextAttributeInRange('B', null, 4, 3)
        ItemRenderer.renderedBodyTextSPANForRenderedLI(viewLI).innerHTML.should.equal('one <b>two</b> three')

      it 'should not crash when offscreen item is changed', ->
        editor.setCollapsed(one)
        four.bodyText = 'one two three'

      it 'should not crash when child is added to offscreen item', ->
        editor.setCollapsed(one)
        four.appendChild(outline.createItem('Boo!'))

      it 'should update correctly when child is inserted into filtered view', ->
        editor.hoistItem(one)
        editor.setSearch('five')

        item = editor.insertItem('Boo!')
        item.nextSibling.should.equal(five)
        renderedItemLI = editorElement.itemRenderer.renderedLIForItem(item)
        renderedItemLI.nextSibling.should.equal(editorElement.itemRenderer.renderedLIForItem(item.nextSibling))

      it 'should update correctly when child is inserted before filtered sibling', ->
        editor.hoistItem(one)
        editor.setSearch('five')

        item = editor.outline.createItem('Boo!')
        one.insertChildBefore(item, one.firstChild)
        renderedItemLI = editorElement.itemRenderer.renderedLIForItem(item)
        nextRenderedItemLI = editorElement.itemRenderer.renderedLIForItem(editor.getNextVisibleSibling(item))
        renderedItemLI.nextSibling.should.equal(nextRenderedItemLI)

    describe 'Editor State', ->
      it 'should render selection state', ->
        li = editorElement.itemRenderer.renderedLIForItem(one)
        editor.moveSelectionRange(one)
        li.classList.contains('ft-item-selected').should.be.true
        editor.moveSelectionRange(two)
        li.classList.contains('ft-item-selected').should.be.false

      it 'should render expanded state', ->
        li = editorElement.itemRenderer.renderedLIForItem(one)
        li.classList.contains('ft-expanded').should.be.true
        editor.setCollapsed(one)
        li.classList.contains('ft-expanded').should.be.false

  describe 'Picking', ->
    it 'should above/before', ->
      rect = editorElement.getBoundingClientRect()
      itemCaretPosition = editorElement.pick(rect.left, rect.top).itemCaretPosition
      itemCaretPosition.locationItem.should.eql(one)
      itemCaretPosition.location.should.eql(0)

    it 'should above/after', ->
      rect = editorElement.getBoundingClientRect()
      itemCaretPosition = editorElement.pick(rect.right, rect.top).itemCaretPosition
      itemCaretPosition.locationItem.should.eql(one)
      itemCaretPosition.location.should.eql(0)

    it 'should below/before', ->
      rect = editorElement.getBoundingClientRect()
      itemCaretPosition = editorElement.pick(rect.left, rect.bottom).itemCaretPosition
      itemCaretPosition.locationItem.should.eql(six)
      itemCaretPosition.location.should.eql(3)

    it 'should below/after', ->
      rect = editorElement.getBoundingClientRect()
      itemCaretPosition = editorElement.pick(rect.right, rect.bottom).itemCaretPosition
      itemCaretPosition.locationItem.should.eql(six)
      itemCaretPosition.location.should.eql(3)

    it 'should pick with no items without stackoverflow', ->
      one.removeFromParent()
      pick = editorElement.pick(0, 0)

    it 'should pick at line wrap boundaries', ->
      LI = editorElement.itemRenderer.renderedLIForItem(one)
      SPAN = ItemRenderer.renderedBodyTextSPANForRenderedLI(LI)
      bounds = SPAN.getBoundingClientRect()
      appendText = ' makethislinewrap'
      newBounds = bounds

      # First grow text in one so that it wraps to next line. So tests
      # will pass no matter what browser window width/font/etc is.
      while bounds.height is newBounds.height
        one.appendBodyText(appendText)
        SPAN = ItemRenderer.renderedBodyTextSPANForRenderedLI(LI)
        newBounds = SPAN.getBoundingClientRect()

      pickRightTop = editorElement.pick(newBounds.right - 1, newBounds.top + 1).itemCaretPosition
      pickLeftBottom = editorElement.pick(newBounds.left + 1, newBounds.bottom - 1).itemCaretPosition

      pickRightTop.selectionAffinity.should.equal('SelectionAffinityUpstream')
      pickLeftBottom.selectionAffinity.should.equal('SelectionAffinityDownstream')

      # Setup problematic special case... when first text to wrap also
      # starts an attribute run.
      length = appendText.length - 1
      start = one.bodyText.length - length
      one.addBodyTextAttributeInRange('I', null, start, length)
      SPAN = ItemRenderer.renderedBodyTextSPANForRenderedLI(LI)

      newBounds = SPAN.getBoundingClientRect()
      pickRightTop = editorElement.pick(newBounds.right - 1, newBounds.top + 1).itemCaretPosition
      pickLeftBottom = editorElement.pick(newBounds.left + 1, newBounds.bottom - 1).itemCaretPosition

      pickRightTop.selectionAffinity.should.equal('SelectionAffinityUpstream')
      pickLeftBottom.selectionAffinity.should.equal('SelectionAffinityDownstream')

  describe 'Offset Encoding', ->
    it 'should translate from outline to DOM locations', ->
      viewLI = document.getElementById(one.id)
      itemRenderer = editorElement.itemRenderer
      SPAN = ItemRenderer.renderedBodyTextSPANForRenderedLI(viewLI)

      itemRenderer.itemOffsetToNodeOffset(one, 0).should.eql
        node: SPAN.firstChild
        location: 0

      itemRenderer.itemOffsetToNodeOffset(one, 2).should.eql
        node: SPAN.firstChild
        location: 2

      one.bodyHTML = 'one <b>two</b> three'

      SPAN = ItemRenderer.renderedBodyTextSPANForRenderedLI(viewLI)
      itemRenderer.itemOffsetToNodeOffset(one, 4).should.eql
        node: SPAN.firstChild
        location: 4

      itemRenderer.itemOffsetToNodeOffset(one, 5).location.should.equal(1)
      itemRenderer.itemOffsetToNodeOffset(one, 7).location.should.equal(3)
      itemRenderer.itemOffsetToNodeOffset(one, 8).location.should.equal(1)

    it 'should translate from DOM to outline', ->
      viewLI = document.getElementById(one.id)
      SPAN = ItemRenderer.renderedBodyTextSPANForRenderedLI(viewLI)

      AttributedString.inlineFTMLIndexToTextIndex(SPAN, 0).should.equal(0)
      AttributedString.inlineFTMLIndexToTextIndex(SPAN.firstChild, 0).should.equal(0)

      one.bodyHTML = 'one <b>two</b> three'
      SPAN = ItemRenderer.renderedBodyTextSPANForRenderedLI(viewLI)

      AttributedString.inlineFTMLIndexToTextIndex(SPAN, 0).should.equal(0)
      AttributedString.inlineFTMLIndexToTextIndex(SPAN, 1).should.equal(4)
      AttributedString.inlineFTMLIndexToTextIndex(SPAN, 2).should.equal(7)

      b = SPAN.firstChild.nextSibling

      AttributedString.inlineFTMLIndexToTextIndex(b, 0).should.equal(4)
      AttributedString.inlineFTMLIndexToTextIndex(b.firstChild, 2).should.equal(6)

      AttributedString.inlineFTMLIndexToTextIndex(SPAN.lastChild, 0).should.equal(7)
      AttributedString.inlineFTMLIndexToTextIndex(SPAN.lastChild, 3).should.equal(10)
