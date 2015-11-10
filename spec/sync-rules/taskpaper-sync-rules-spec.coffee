loadOutlineFixture = require '../load-outline-fixture'
TaskPaper = require '../../lib/taskpaper'
Outline = require '../../lib/core/outline'

describe 'TaskPaper Sync Rules', ->
  [editor, outline, root, one, two, three, four, five, six] = []

  beforeEach ->
    {outline, root, one, two, three, four, five, six} = loadOutlineFixture()
    TaskPaper.initOutline(outline)

  describe 'Body text to attributes', ->

    it 'should sync project sytax to data-type="project"', ->
      one.bodyString = 'my project:'
      one.getAttribute('data-type').should.equal('project')
      one.bodyHighlightedAttributedString.toString().should.equal('(my project:)')

    it 'should sync task sytax to data-type="task"', ->
      one.bodyString = '- my task'
      one.getAttribute('data-type').should.equal('task')
      one.bodyHighlightedAttributedString.toString().should.equal('(-/url:"button://toggledone")( my task)')

    it 'should sync note sytax to data-type="note"', ->
      one.bodyString = 'my note'
      one.getAttribute('data-type').should.equal('note')

    it 'should sync tags to data- attributes', ->
      one.bodyString = '@jesse(washere)'
      one.getAttribute('data-jesse').should.equal('washere')
      one.bodyString = '@jesse(washere) @2'
      one.getAttribute('data-jesse').should.equal('washere')
      one.getAttribute('data-2').should.equal('')
      one.bodyHighlightedAttributedString.toString().should.equal('(@jesse/tag:""/tagname:"data-jesse"/url:"filter://@jesse")((/tag:"")(washere/tag:""/tagvalue:"washere"/url:"filter://@jesse = washere")()/tag:"")( )(@2/tag:""/tagname:"data-2"/url:"filter://@2")')
      one.bodyString = 'no tags here'
      expect(one.getAttribute('data-jesse')).toBeUndefined()
      expect(one.getAttribute('data-2')).toBeUndefined()

    it 'should undo sync body text to attribute', ->
      one.bodyString = '@jesse(washere)'
      outline.undoManager.undo()
      one.bodyString.should.equal('one')
      expect(one.getAttribute('data-jesse')).toBeUndefined()
      outline.undoManager.redo()
      one.bodyString.should.equal('@jesse(washere)')
      one.getAttribute('data-jesse').should.equal('washere')

    it 'should undo coaleced sync body text attributes', ->
      one.replaceBodyRange(3, 0, ' ')
      one.replaceBodyRange(4, 0, '@')
      one.replaceBodyRange(5, 0, 'a')
      one.getAttribute('data-a').should.equal('')
      one.replaceBodyRange(6, 0, 'b')
      one.getAttribute('data-ab').should.equal('')
      outline.undoManager.undo()
      one.bodyString.should.equal('one')

  describe 'Attributes to body text', ->

    it 'should sync data-type="task" to task syntax', ->
      one.setAttribute('data-type', 'task')
      one.bodyString.should.equal('- one')
      one.getAttribute('data-type').should.equal('task')
      one.bodyHighlightedAttributedString.toString().should.equal('(-/url:"button://toggledone")( one)')

    it 'should sync data-type="project" to project syntax', ->
      one.setAttribute('data-type', 'project')
      one.bodyString.should.equal('one:')
      one.getAttribute('data-type').should.equal('project')

    it 'should sync data-type="note" to note syntax', ->
      one.setAttribute('data-type', 'note')
      one.bodyString.should.equal('one')
      one.getAttribute('data-type').should.equal('note')

    it 'should sync between multiple data-types', ->
      one.setAttribute('data-type', 'note')
      one.bodyString.should.equal('one')
      one.setAttribute('data-type', 'project')
      one.bodyString.should.equal('one:')
      one.setAttribute('data-type', 'task')
      one.bodyString.should.equal('- one')
      one.setAttribute('data-type', 'project')
      one.bodyString.should.equal('one:')
      one.setAttribute('data-type', 'note')
      one.bodyString.should.equal('one')

    it 'should sync data- attributes to tags', ->
      one.setAttribute('data-jesse', 'washere')
      one.bodyString.should.equal('one @jesse(washere)')
      one.setAttribute('data-moose', '')
      one.bodyString.should.equal('one @jesse(washere) @moose')
      one.setAttribute('data-jesse', '')
      one.bodyString.should.equal('one @jesse @moose')
      one.removeAttribute('data-jesse', '')
      one.bodyString.should.equal('one @moose')
      one.setAttribute('data-moose', 'mouse')
      one.bodyString.should.equal('one @moose(mouse)')
      one.bodyHighlightedAttributedString.toString().should.equal('(one )(@moose/tag:""/tagname:"data-moose"/url:"filter://@moose")((/tag:"")(mouse/tag:""/tagvalue:"mouse"/url:"filter://@moose = mouse")()/tag:"")')

    it 'should sync data- attributes to tags and change type if type changes', ->
      one.bodyString = 'one:'
      one.setAttribute('data-moose', '')
      one.getAttribute('data-type').should.equal('note')

    it 'should undo sync data- attributes to tags', ->
      one.setAttribute('data-type', 'project')
      outline.undoManager.undo()
      one.bodyString.should.equal('one')
      outline.undoManager.redo()
      one.bodyString.should.equal('one:')
      one.getAttribute('data-type').should.equal('project')
