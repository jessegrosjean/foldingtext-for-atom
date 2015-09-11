LineBuffer = require '../../lib/core/line-buffer'

describe 'LineBuffer', ->
  [lineBuffer, bufferSubscription, indexDidChangeExpects] = []

  beforeEach ->
    lineBuffer = new LineBuffer()
    bufferSubscription = lineBuffer.onDidChange (e) ->
      if indexDidChangeExpects?.length
        exp = indexDidChangeExpects.shift()
        exp(e)

  afterEach ->
    expect(indexDidChangeExpects?.length).toBeFalsy()
    indexDidChangeExpects = null
    bufferSubscription.dispose()
    lineBuffer.destroy()

  it 'starts empty', ->
    lineBuffer.getLength().should.equal(0)
    lineBuffer.getLineCount().should.equal(0)
    lineBuffer.toString().should.equal('')

  describe 'Insert Text', ->

    it 'creates line for string with no newlines', ->
      lineBuffer.insertString(0, 'one')
      lineBuffer.toString().should.equal('(one)')

    it 'creates lines for string with single newline', ->
      lineBuffer.insertString(0, 'one\ntwo')
      lineBuffer.toString().should.equal('(one\n)(two)')

    it 'creates lines for string with multiple newlines', ->
      lineBuffer.insertString(0, 'one\ntwo\n')
      lineBuffer.toString().should.equal('(one\n)(two\n)()')

    it 'inserts just about anywhere and still works', ->
      lineBuffer.insertString(0, 'one\ntwo')

      lineBuffer.insertString(7, '\n')
      lineBuffer.toString().should.equal('(one\n)(two\n)()')

      lineBuffer.insertString(0, '\n')
      lineBuffer.toString().should.equal('(\n)(one\n)(two\n)()')

      lineBuffer.insertString(9, 'a\n')
      lineBuffer.toString().should.equal('(\n)(one\n)(two\n)(a\n)()')

      lineBuffer.insertString(2, '\na\n')
      lineBuffer.toString().should.equal('(\n)(o\n)(a\n)(ne\n)(two\n)(a\n)()')

  describe 'Delete Text', ->

    it 'joins lines when separating \n is deleted', ->
      lineBuffer.insertString(0, 'one\ntwo')
      lineBuffer.deleteRange(3, 1)
      lineBuffer.toString().should.equal('(onetwo)')

    it 'joins trailing end line when separating \n is deleted', ->
      lineBuffer.insertString(0, 'one\ntwo\n')
      lineBuffer.deleteRange(7, 1)
      lineBuffer.toString().should.equal('(one\n)(two)')

    it 'removes line when its text is fully deleted', ->
      lineBuffer.insertString(0, 'one\ntwo\nthree')
      lineBuffer.deleteRange(4, 4)
      lineBuffer.toString().should.equal('(one\n)(three)')

  describe 'Replace Text', ->

    it 'replaces text', ->
      lineBuffer.insertString(0, 'Hello world!')
      lineBuffer.replaceRange(3, 5, '')
      lineBuffer.toString().should.equal('(Helrld!)')

  describe 'Spans', ->

    it 'adds newline to last span when spans inserted after it', ->
      lineBuffer.insertSpans(0, [lineBuffer.createSpan('one'), lineBuffer.createSpan('two')])
      lineBuffer.insertSpans(0, [lineBuffer.createSpan('zero')])
      lineBuffer.insertSpans(3, [lineBuffer.createSpan('three')])
      lineBuffer.toString().should.equal('(zero\n)(one\n)(two\n)(three)')

    it 'removes newline from span when it becomes the last span', ->
      lineBuffer.insertString(0, 'one\ntwo\nthree')
      lineBuffer.removeSpans(0, 1)
      lineBuffer.toString().should.equal('(two\n)(three)')
      lineBuffer.removeSpans(1, 1)
      lineBuffer.toString().should.equal('(two)')

  describe 'Events', ->

    it 'posts change events when updating text in line', ->
      lineBuffer.insertSpans 0, [
        lineBuffer.createSpan('a'),
        lineBuffer.createSpan('b'),
        lineBuffer.createSpan('c')
      ]
      indexDidChangeExpects = [
        (e) ->
          e.location.should.equal(0)
          e.replacedLength.should.equal(1)
          e.insertedString.should.equal('moose')
      ]
      lineBuffer.replaceRange(0, 1, 'moose')

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
      lineBuffer.insertSpans 0, [
        lineBuffer.createSpan('a'),
        lineBuffer.createSpan('b'),
        lineBuffer.createSpan('c')
      ]
      lineBuffer.insertSpans 3, [
        lineBuffer.createSpan('d')
      ]

    it 'posts change events when removing lines', ->
      lineBuffer.insertSpans 0, [
        lineBuffer.createSpan('a'),
        lineBuffer.createSpan('b'),
        lineBuffer.createSpan('c')
      ]
      indexDidChangeExpects = [
        (e) ->
          e.location.should.equal(3)
          e.replacedLength.should.equal(2)
          e.insertedString.should.equal('')
      ]
      lineBuffer.removeSpans(2, 1)

    it 'posts change events when removing all lines', ->
      lineBuffer.insertSpans 0, [
        lineBuffer.createSpan('a'),
        lineBuffer.createSpan('b'),
        lineBuffer.createSpan('c')
      ]
      indexDidChangeExpects = [
        (e) ->
          e.location.should.equal(0)
          e.replacedLength.should.equal(5)
          e.insertedString.should.equal('')
      ]
      lineBuffer.removeSpans(0, 3)