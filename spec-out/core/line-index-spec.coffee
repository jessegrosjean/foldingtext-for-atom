LineIndex = require '../../lib/core/line-index'

describe 'LineIndex', ->
  [lineIndex] = []

  beforeEach ->
    lineIndex = new LineIndex()

  afterEach ->
    lineIndex.destroy()

  it 'starts empty', ->
    lineIndex.getLength().should.equal(0)
    lineIndex.getLineCount().should.equal(0)

  it 'creates line for string with no newlines', ->
    lineIndex.string = 'one'
    lineIndex.insertString(0, 'one')
    lineIndex.getLength().should.equal('one'.length)
    lineIndex.getLineCount().should.equal(1)

  it 'creates lines for string with single newline', ->
    lineIndex.string = 'one\ntwo'
    lineIndex.insertString(0, 'one\ntwo')
    lineIndex.getLength().should.equal('one\ntwo'.length)
    lineIndex.getLineCount().should.equal(2)

  it 'creates lines for string with multiple newlines', ->
    lineIndex.string = 'one\ntwo\n'
    lineIndex.insertString(0, 'one\ntwo\n')
    lineIndex.getLength().should.equal('one\ntwo\n'.length)
    lineIndex.getLineCount().should.equal(3)

  it 'remove lines for deleted text', ->
    lineIndex.string = 'one\ntwo\n'
    lineIndex.insertString(0, 'one\ntwo\n')

    lineIndex.string = 'one\ntwo'
    lineIndex.deleteRange(7, '\n'.length)
    lineIndex.getLength().should.equal('one\ntwo'.length)
    lineIndex.getLineCount().should.equal(2)

    lineIndex.string = 'onewo'
    lineIndex.deleteRange(3, '\nt'.length)
    lineIndex.getLength().should.equal('onewo'.length)
    lineIndex.getLineCount().should.equal(1)
