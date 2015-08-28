TaskPaperSyncRules = require '../../lib/sync-rules/taskpaper-sync-rules'
loadOutlineFixture = require '../load-outline-fixture'
Outline = require '../../lib/core/outline'

describe 'TaskPaper Sync Rules', ->
  [editor, outline, root, one, two, three, four, five, six] = []

  beforeEach ->
    {outline, root, one, two, three, four, five, six} = loadOutlineFixture()
    outline.registerAttributeBodyTextSyncRule(TaskPaperSyncRules)

  describe 'Body text to attributes', ->

    it 'should sync project sytax to data-type="project"', ->
      one.bodyText = 'my project:'
      one.getAttribute('data-type').should.equal('project')

    it 'should sync task sytax to data-type="task"', ->
      one.bodyText = '- my task:'
      one.getAttribute('data-type').should.equal('task')

    it 'should sync note sytax to data-type="note"', ->
      one.bodyText = 'my note'
      one.getAttribute('data-type').should.equal('note')

    it 'should sync tags to data- attributes', ->
      one.bodyText = '@jesse(washere)'
      one.getAttribute('data-jesse').should.equal('washere')
      one.bodyText = '@jesse(washere) @moose'
      one.getAttribute('data-jesse').should.equal('washere')
      one.getAttribute('data-moose').should.equal('')
      one.bodyText = 'no tags here'
      expect(one.getAttribute('data-jesse')).toBeNull()
      expect(one.getAttribute('data-moose')).toBeNull()

  describe 'Attributes to body text', ->

    it 'should sync data-type="task" to task syntax', ->
      one.setAttribute('data-type', 'task')
      one.bodyText.should.equal('- one')

    it 'should sync data-type="project" to project syntax', ->
      one.setAttribute('data-type', 'project')
      one.bodyText.should.equal('one:')

    it 'should sync data-type="note" to note syntax', ->
      one.setAttribute('data-type', 'note')
      one.bodyText.should.equal('one')

    it 'should sync between multiple data-types', ->
      one.setAttribute('data-type', 'note')
      one.bodyText.should.equal('one')
      one.setAttribute('data-type', 'project')
      one.bodyText.should.equal('one:')
      one.setAttribute('data-type', 'task')
      one.bodyText.should.equal('- one')
      one.setAttribute('data-type', 'project')
      one.bodyText.should.equal('one:')
      one.setAttribute('data-type', 'note')
      one.bodyText.should.equal('one')

    it 'should sync data- attributes to tags', ->
      one.setAttribute('data-jesse', 'washere')
      one.bodyText.should.equal('one @jesse(washere)')
      one.setAttribute('data-moose', '')
      one.bodyText.should.equal('one @jesse(washere) @moose')
      one.setAttribute('data-jesse', '')
      one.bodyText.should.equal('one @jesse @moose')
      one.removeAttribute('data-jesse', '')
      one.bodyText.should.equal('one @moose')
      one.setAttribute('data-moose', 'mouse')
      one.bodyText.should.equal('one @moose(mouse)')
