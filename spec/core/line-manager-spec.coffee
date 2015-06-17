LineManager = require '../../lib/core/line-manager'

describe 'LineManager', ->
  [lineManager, lines] = []

  beforeEach ->
    lines = []
    for each in [0...500]
      lines.push new LineManager.Line({}, 5)
    lineManager = new LineManager(lines)

  it 'starts empty', ->
    expect(lineManager.getLineCount()).toBe(0)
    expect(lineManager.getCharacterCount()).toBe(0)

  it 'inserts lines', ->
    lineManager.insertLines(0, lines)
    expect(lineManager.getLineCount()).toBe(500)
    expect(lineManager.getCharacterCount()).toBe(2999)

  it 'removes lines', ->
    lineManager.insertLines(0, lines)
    lineManager.removeLines(0, 2)
    expect(lineManager.getLineCount()).toBe(498)
    expect(lineManager.getCharacterCount()).toBe(2989)
    lineManager.removeLines(200, 60)
    expect(lineManager.getLineCount()).toBe(438)
    expect(lineManager.getCharacterCount()).toBe(2689)

  it 'updates line character counts', ->
    lineManager.insertLines(0, lines)
    lines[0].setCharacterCount(0) # -5
    lines[241].setCharacterCount(10) # +5
    expect(lineManager.getCharacterCount()).toBe(2999)

  it 'iterates over lines', ->
    lineManager.insertLines(0, lines)

    index = 0
    length = 499
    lineManager.iterateLines index, length, (each) ->
      expect(each).toEqual(lines[index])
      index++

    index = 365
    length = 100
    lineManager.iterateLines index, length, (each) ->
      expect(each).toEqual(lines[index])
      index++

  it 'gets line at line number', ->
    lineManager.insertLines(0, lines)
    expect(lineManager.getLine(0)).toEqual(lines[0])
    expect(lineManager.getLine(1)).toEqual(lines[1])
    expect(lineManager.getLine(312)).toEqual(lines[312])
    expect(lineManager.getLine(499)).toEqual(lines[499])

  it 'gets line number of line', ->
    lineManager.insertLines(0, lines)
    expect(lineManager.getLineNumber(lines[0])).toEqual(0)
    expect(lineManager.getLineNumber(lines[1])).toEqual(1)
    expect(lineManager.getLineNumber(lines[50])).toEqual(50)
    expect(lineManager.getLineNumber(lines[51])).toEqual(51)
    expect(lineManager.getLineNumber(lines[253])).toEqual(253)
    expect(lineManager.getLineNumber(lines[499])).toEqual(499)

  it 'gets character offset of line', ->
    lineManager.insertLines(0, lines)
    expect(lineManager.getCharacterOffset(lines[0])).toEqual(0)
    expect(lineManager.getCharacterOffset(lines[1])).toEqual(6)
    expect(lineManager.getCharacterOffset(lines[50])).toEqual(300)
    expect(lineManager.getCharacterOffset(lines[51])).toEqual(306)
    expect(lineManager.getCharacterOffset(lines[253])).toEqual(1518)
    expect(lineManager.getCharacterOffset(lines[499])).toEqual(2994)

  it 'gets line character offset at global character offset', ->
    lineManager.insertLines(0, lines)
    expect(lineManager.getLineCharacterOffset(0)).toEqual({line: lines[0], characterOffset: 0})
    expect(lineManager.getLineCharacterOffset(3)).toEqual({line: lines[0], characterOffset: 3})
    expect(lineManager.getLineCharacterOffset(5)).toEqual({line: lines[0], characterOffset: 5})
    expect(lineManager.getLineCharacterOffset(6)).toEqual({line: lines[1], characterOffset: 0})
    expect(lineManager.getLineCharacterOffset(lineManager.getCharacterCount())).toEqual({line: lines[499], characterOffset: 5})

  it 'gets line number of line', ->
    lineManager.insertLines(0, lines)
