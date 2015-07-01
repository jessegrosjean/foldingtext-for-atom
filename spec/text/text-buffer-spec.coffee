TextBuffer = require '../../lib/text/text-buffer'
Range = require '../../lib/text/range'
Line = require '../../lib/text/line'

describe 'TextBuffer', ->
  [textBuffer, lines] = []

  beforeEach ->
    lines = []
    for each in [0...500]
      lines.push new Line('12345', 5)
    textBuffer = new TextBuffer()

  it 'starts empty', ->
    expect(textBuffer.getText()).toBe('')
    expect(textBuffer.getLineCount()).toBe(0)
    expect(textBuffer.getCharacterCount()).toBe(0)

  describe 'Lines', ->

    it 'inserts lines', ->
      textBuffer.insertLines(0, lines)
      expect(textBuffer.getLineCount()).toBe(500)
      expect(textBuffer.getCharacterCount()).toBe((500 * 6) - 1)
      expect(textBuffer.getText().length).toBe((500 * 6) - 1)

    it 'removes lines', ->
      textBuffer.insertLines(0, lines)
      textBuffer.removeLines(0, 2)
      expect(textBuffer.getLineCount()).toBe(498)
      expect(textBuffer.getCharacterCount()).toBe((498 * 6) - 1)
      expect(textBuffer.getText().length).toBe((498 * 6) - 1)
      textBuffer.removeLines(200, 60)
      expect(textBuffer.getLineCount()).toBe(438)
      expect(textBuffer.getCharacterCount()).toBe((438 * 6) - 1)
      expect(textBuffer.getText().length).toBe((438 * 6) - 1)

    it 'updates line character counts', ->
      textBuffer.insertLines(0, lines)
      lines[0].setCharacterCount(0) # -5
      lines[241].setCharacterCount(10) # +5
      expect(textBuffer.getText().length).toBe((500 * 6) - 1)
      expect(textBuffer.getCharacterCount()).toBe((500 * 6) - 1)

    it 'iterates over lines', ->
      textBuffer.insertLines(0, lines)

      index = 0
      count = 0
      length = 499
      textBuffer.iterateLines index, length, (each) ->
        expect(each).toEqual(lines[index])
        index++
        count++
      expect(count).toBe(499)

      index = 365
      count = 0
      length = 100
      textBuffer.iterateLines index, length, (each) ->
        expect(each).toEqual(lines[index])
        index++
        count++
      expect(count).toBe(100)

    it 'gets line at row', ->
      textBuffer.insertLines(0, lines)
      expect(textBuffer.getLine(0)).toEqual(lines[0])
      expect(textBuffer.getLine(1)).toEqual(lines[1])
      expect(textBuffer.getLine(312)).toEqual(lines[312])
      expect(textBuffer.getLine(499)).toEqual(lines[499])

    it 'gets row of line', ->
      textBuffer.insertLines(0, lines)
      expect(textBuffer.getRow(lines[0])).toEqual(0)
      expect(textBuffer.getRow(lines[1])).toEqual(1)
      expect(textBuffer.getRow(lines[50])).toEqual(50)
      expect(textBuffer.getRow(lines[51])).toEqual(51)
      expect(textBuffer.getRow(lines[253])).toEqual(253)
      expect(textBuffer.getRow(lines[499])).toEqual(499)

    it 'gets character offset of line', ->
      textBuffer.insertLines(0, lines)
      expect(textBuffer.getCharacterOffset(lines[0])).toEqual(0)
      expect(textBuffer.getCharacterOffset(lines[1])).toEqual(6)
      expect(textBuffer.getCharacterOffset(lines[50])).toEqual(300)
      expect(textBuffer.getCharacterOffset(lines[51])).toEqual(306)
      expect(textBuffer.getCharacterOffset(lines[253])).toEqual(1518)
      expect(textBuffer.getCharacterOffset(lines[499])).toEqual(2994)

    it 'gets line character offset at global character offset', ->
      textBuffer.insertLines(0, lines)
      expect(textBuffer.getLineCharacterOffset(0)).toEqual({line: lines[0], characterOffset: 0})
      expect(textBuffer.getLineCharacterOffset(3)).toEqual({line: lines[0], characterOffset: 3})
      expect(textBuffer.getLineCharacterOffset(5)).toEqual({line: lines[0], characterOffset: 5})
      expect(textBuffer.getLineCharacterOffset(6)).toEqual({line: lines[1], characterOffset: 0})
      expect(textBuffer.getLineCharacterOffset(textBuffer.getCharacterCount())).toEqual({line: lines[499], characterOffset: 5})

  describe 'Text', ->

    it 'get text from single line ranges', ->
      textBuffer.insertLines(0, lines)
      expect(textBuffer.getTextInRange([[0, 0], [0, 1]])).toBe('1')
      expect(textBuffer.getTextInRange([[0, 0], [0, 2]])).toBe('12')
      expect(textBuffer.getTextInRange([[0, 1], [0, 2]])).toBe('2')
      expect(textBuffer.getTextInRange([[0, 2], [0, Number.MAX_VALUE]])).toBe('345')

    it 'gets text from multi line ranges', ->
      textBuffer.insertLines(0, lines)
      expect(textBuffer.getTextInRange([[0, 0], [1, 0]])).toBe('12345\n')
      expect(textBuffer.getTextInRange([[0, 5], [1, 0]])).toBe('\n')
      expect(textBuffer.getTextInRange([[0, 3], [1, 3]])).toBe('45\n123')

    it 'replaces text in single line range', ->
      textBuffer.insertLines(0, lines)
      textBuffer.setTextInRange('z', [[0, 0], [0, 1]])
      expect(textBuffer.getLineCount()).toBe(500)
      expect(textBuffer.getCharacterCount()).toBe((500 * 6) - 1)
      expect(textBuffer.getText().length).toBe((500 * 6) - 1)
      expect(textBuffer.getText()[0]).toBe('z')

    it 'inserts multiple lines text in single line range', ->
      textBuffer.insertLines(0, lines)
      textBuffer.setTextInRange('one\ntwo', [[0, 0], [0, 1]])
      expect(textBuffer.getLineCount()).toBe(501)
      expect(textBuffer.getCharacterCount()).toBe(3005)
      expect(textBuffer.getText().length).toBe(3005)

    it 'replaces text in multi line range', ->
      textBuffer.insertLines(0, lines)
      textBuffer.setTextInRange('', [[0, 3], [4, 1]])
      expect(textBuffer.getLineCount()).toBe(496)
      expect(textBuffer.getCharacterCount()).toBe(2977)
      expect(textBuffer.getText().length).toBe(2977)
