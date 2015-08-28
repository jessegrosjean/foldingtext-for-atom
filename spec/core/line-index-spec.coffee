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

  it 'creates lines for inserted text', ->
    lineIndex.stringStore = 'one\ntwo\n'
    lineIndex.insertText(0, 'one\ntwo\n')
    lineIndex.getLength().should.equal('one\ntwo\n'.length)
    lineIndex.getLineCount().should.equal(3)

  it 'remove lines for deleted text', ->
    lineIndex.stringStore = 'one\ntwo\n'
    lineIndex.insertText(0, 'one\ntwo\n')

    lineIndex.stringStore = 'one\ntwo'
    lineIndex.deleteText(7, '\n'.length)
    lineIndex.getLength().should.equal('one\ntwo'.length)
    lineIndex.getLineCount().should.equal(2)

    lineIndex.stringStore = 'onewo'
    lineIndex.deleteText(3, '\nt'.length)
    lineIndex.getLength().should.equal('onewo'.length)
    lineIndex.getLineCount().should.equal(1)
