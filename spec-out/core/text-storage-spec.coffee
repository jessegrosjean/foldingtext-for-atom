TextStorage = require '../../lib/core/text-storage'

describe 'TextStorage', ->
  [textStorage] = []

  beforeEach ->
    textStorage = new TextStorage()

  afterEach ->
    textStorage.destroy()

  it 'starts empty', ->
    textStorage.getLength().should.equal(0)
    textStorage.toString().should.equal('[string: ] [lines: length: 0 spans: ] [runs: length: 0 spans: ]')

  it 'inserts text', ->
    textStorage.insertString(0, 'one')
    textStorage.insertString(2, 'moose')
    textStorage.toString().should.equal('[string: onmoosee] [lines: length: 8 spans: 0-7] [runs: length: 8 spans: 0-7/]')

  it 'deletes text', ->
    textStorage.insertString(0, 'one')
    textStorage.deleteRange(1, 1)
    textStorage.toString().should.equal('[string: oe] [lines: length: 2 spans: 0-1] [runs: length: 2 spans: 0-1/]')

  it 'gets subtextStorage', ->
    textStorage.insertString(0, 'one\ntwo')
    textStorage.addAttributeInRange('a', 'a', 0, 5)
    textStorage.addAttributeInRange('b', 'b', 2, 5)
    textStorage.toString().should.equal('[string: one\ntwo] [lines: length: 7 spans: 0-3, 4-6] [runs: length: 7 spans: 0-1/a=a, 2-4/a=a/b=b, 5-6/b=b]')
    textStorage.subtextStorage(0, 2).toString().should.equal('[string: on] [lines: length: 2 spans: 0-1] [runs: length: 2 spans: 0-1/a=a]')
    textStorage.subtextStorage(0, 1).toString().should.equal('[string: o] [lines: length: 1 spans: 0] [runs: length: 1 spans: 0/a=a]')
    textStorage.subtextStorage(1, 4).toString().should.equal('[string: ne\nt] [lines: length: 4 spans: 0-2, 3] [runs: length: 4 spans: 0/a=a, 1-3/a=a/b=b]')

  it 'appends textStorage', ->
    textStorage.insertString(0, 'one')
    textStorage.addAttributeInRange('a', 'a', 0, 3)
    append = new TextStorage()
    append.insertString(0, 'two')
    append.addAttributeInRange('b', 'b', 0, 3)
    textStorage.appendTextStorage(append)
    textStorage.toString().should.equal('[string: onetwo] [lines: length: 6 spans: 0-5] [runs: length: 6 spans: 0-2/a=a, 3-5/b=b]')

  it 'inserts textStorage', ->
    textStorage.insertString(0, 'one')
    textStorage.addAttributeInRange('a', 'a', 0, 3)
    insert = new TextStorage()
    insert.insertString(0, 'two')
    insert.addAttributeInRange('b', 'b', 0, 3)
    textStorage.insertTextStorage(2, insert)
    textStorage.toString().should.equal('[string: ontwoe] [lines: length: 6 spans: 0-5] [runs: length: 6 spans: 0-1/a=a, 2-4/b=b, 5/a=a]')