TaskPaperSyncRules = require '../../lib/sync-rules/taskpaper-sync-rules'
loadOutlineFixture = require '../load-outline-fixture'
Outline = require '../../lib/core/outline'

fdescribe 'TaskPaper Sync Rules', ->
  [editor, outline, root, one, two, three, four, five, six] = []

  beforeEach ->
    {outline, root, one, two, three, four, five, six} = loadOutlineFixture()
    outline.registerAttributeBodyTextSyncRule(TaskPaperSyncRules)

  it 'sync body text tags to attributes', ->
    one.bodyText = '@jesse(washere)'
    one.getAttribute('jesse').should.equal('washere')

  it 'sync body text tags to attributes', ->
    one.bodyText = '@jesse(washere)'
    one.getAttribute('jesse').should.equal('washere')
    one.bodyText = '@jesse(washere) @moose'
    one.getAttribute('jesse').should.equal('washere')
    one.getAttribute('moose').should.equal('')
    one.bodyText = 'no tags here'
    expect(one.getAttribute('jesse')).toBeNull()
    expect(one.getAttribute('moose')).toBeNull()

  it 'sync attributes to body text', ->
    one.setAttribute('jesse', 'washere')
    one.bodyText.should.equal('one @jesse(washere)')
    one.setAttribute('moose', '')
    one.bodyText.should.equal('one @jesse(washere) @moose')
    one.setAttribute('jesse', '')
    one.bodyText.should.equal('one @jesse @moose')
    one.removeAttribute('jesse', '')
    one.bodyText.should.equal('one @moose')
    one.setAttribute('moose', 'mouse')
    one.bodyText.should.equal('one @moose(mouse)')
