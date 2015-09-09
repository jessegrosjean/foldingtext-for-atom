LineIndex = require '../../lib/core/line-index'

describe 'LineIndex', ->
  [lineIndex, indexSubscription, indexDidChangeExpects] = []

  beforeEach ->
    lineIndex = new LineIndex()
    indexSubscription = lineIndex.onDidChange (e) ->
      if indexDidChangeExpects?.length
        exp = indexDidChangeExpects.shift()
        exp(e)

  afterEach ->
    expect(indexDidChangeExpects?.length).toBeFalsy()
    indexDidChangeExpects = null
    indexSubscription.dispose()
    lineIndex.destroy()

  it 'starts empty', ->
    lineIndex.getLength().should.equal(0)
    lineIndex.getLineCount().should.equal(0)
    lineIndex.toString().should.equal('')

  describe 'Insert Text', ->

    it 'creates line for string with no newlines', ->
      lineIndex.insertString(0, 'one')
      lineIndex.toString().should.equal('(one)')

    it 'creates lines for string with single newline', ->
      lineIndex.insertString(0, 'one\ntwo')
      lineIndex.toString().should.equal('(one\n)(two)')

    it 'creates lines for string with multiple newlines', ->
      lineIndex.insertString(0, 'one\ntwo\n')
      lineIndex.toString().should.equal('(one\n)(two\n)()')

    it 'inserts just about anywhere and still works', ->
      lineIndex.insertString(0, 'one\ntwo')

      lineIndex.insertString(7, '\n')
      lineIndex.toString().should.equal('(one\n)(two\n)()')

      lineIndex.insertString(0, '\n')
      lineIndex.toString().should.equal('(\n)(one\n)(two\n)()')

      lineIndex.insertString(9, 'a\n')
      lineIndex.toString().should.equal('(\n)(one\n)(two\n)(a\n)()')

      lineIndex.insertString(2, '\na\n')
      lineIndex.toString().should.equal('(\n)(o\n)(a\n)(ne\n)(two\n)(a\n)()')

  describe 'Delete Text', ->

    it 'joins lines when separating \n is deleted', ->
      lineIndex.insertString(0, 'one\ntwo')
      lineIndex.deleteRange(3, 1)
      lineIndex.toString().should.equal('(onetwo)')

    it 'joins trailing end line when separating \n is deleted', ->
      lineIndex.insertString(0, 'one\ntwo\n')
      lineIndex.deleteRange(7, 1)
      lineIndex.toString().should.equal('(one\n)(two)')

    it 'removes line when its text is fully deleted', ->
      lineIndex.insertString(0, 'one\ntwo\nthree')
      lineIndex.deleteRange(4, 4)
      lineIndex.toString().should.equal('(one\n)(three)')

  describe 'Replace Text', ->

    it 'replaces text', ->
      lineIndex.insertString(0, 'Hello world!')
      lineIndex.replaceRange(3, 5, '')
      lineIndex.toString().should.equal('(Helrld!)')

  describe 'Spans', ->

    it 'adds newline to last span when spans inserted after it', ->
      lineIndex.insertSpans(0, [lineIndex.createSpan('one'), lineIndex.createSpan('two')])
      lineIndex.insertSpans(0, [lineIndex.createSpan('zero')])
      lineIndex.insertSpans(3, [lineIndex.createSpan('three')])
      lineIndex.toString().should.equal('(zero\n)(one\n)(two\n)(three)')

    it 'removes newline from span when it becomes the last span', ->
      lineIndex.insertString(0, 'one\ntwo\nthree')
      lineIndex.removeSpans(0, 1)
      lineIndex.toString().should.equal('(two\n)(three)')
      lineIndex.removeSpans(1, 1)
      lineIndex.toString().should.equal('(two)')

  describe 'Events', ->

    it 'posts change events when updating text in line', ->
      lineIndex.insertSpans 0, [
        lineIndex.createSpan('a'),
        lineIndex.createSpan('b'),
        lineIndex.createSpan('c')
      ]
      indexDidChangeExpects = [
        (e) ->
          e.location.should.equal(0)
          e.replacedLength.should.equal(1)
          e.insertedString.should.equal('moose')
      ]
      lineIndex.replaceRange(0, 1, 'moose')

    it 'posts change events when inserting lines', ->
      indexDidChangeExpects = [
        (e) ->
          e.location.should.equal(0)
          e.replacedLength.should.equal(0)
          e.insertedString.should.equal('a\nb\nc')
        (e) ->
          e.location.should.equal(5)
          e.replacedLength.should.equal(0)
          e.insertedString.should.equal('\nd')
      ]
      lineIndex.insertSpans 0, [
        lineIndex.createSpan('a'),
        lineIndex.createSpan('b'),
        lineIndex.createSpan('c')
      ]
      lineIndex.insertSpans 3, [
        lineIndex.createSpan('d')
      ]

    it 'posts change events when removing lines', ->
      lineIndex.insertSpans 0, [
        lineIndex.createSpan('a'),
        lineIndex.createSpan('b'),
        lineIndex.createSpan('c')
      ]
      indexDidChangeExpects = [
        (e) ->
          e.location.should.equal(3)
          e.replacedLength.should.equal(2)
          e.insertedString.should.equal('')
      ]
      lineIndex.removeSpans(2, 1)

    it 'posts change events when removing all lines', ->
      lineIndex.insertSpans 0, [
        lineIndex.createSpan('a'),
        lineIndex.createSpan('b'),
        lineIndex.createSpan('c')
      ]
      indexDidChangeExpects = [
        (e) ->
          e.location.should.equal(0)
          e.replacedLength.should.equal(5)
          e.insertedString.should.equal('')
      ]
      lineIndex.removeSpans(0, 3)