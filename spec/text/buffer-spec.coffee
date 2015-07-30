Buffer = require '../../lib/text/buffer'
Range = require '../../lib/text/range'
{CompositeDisposable} = require 'atom'
Line = require '../../lib/text/line'

describe 'Buffer', ->
  [buffer, lines] = []

  beforeEach ->
    lines = []
    for each in [0...500]
      lines.push new Line('12345', 5)
    buffer = new Buffer()

  afterEach ->
    buffer.destroy()

  describe 'Init', ->

    it 'starts empty', ->
      expect(buffer.getText()).toBe('')
      expect(buffer.getLineCount()).toBe(0)
      expect(buffer.getCharacterCount()).toBe(0)
      expect(buffer.getRange().toString()).toBe('[(0, 0) - (0, 0)]')
      expect(buffer.getRangeFromCharacterRange(0, 0).toString()).toBe('[(0, 0) - (0, 0)]')

  describe 'Text', ->

    it 'get text from single line ranges', ->
      buffer.insertLines(0, lines)
      expect(buffer.getTextInRange([[0, 0], [0, 1]])).toBe('1')
      expect(buffer.getTextInRange([[0, 0], [0, 2]])).toBe('12')
      expect(buffer.getTextInRange([[0, 1], [0, 2]])).toBe('2')
      expect(buffer.getTextInRange([[0, 2], [0, Number.MAX_VALUE]])).toBe('345')

    it 'gets text from multi line ranges', ->
      buffer.insertLines(0, lines)
      expect(buffer.getTextInRange([[0, 0], [1, 0]])).toBe('12345\n')
      expect(buffer.getTextInRange([[0, 5], [1, 0]])).toBe('\n')
      expect(buffer.getTextInRange([[0, 3], [1, 3]])).toBe('45\n123')

    it 'replaces text in empty buffer', ->
      buffer.setTextInRange('hello', [[0, 0], [0, 0]])
      expect(buffer.getText()).toBe('hello')

    it 'replaces text in single line range', ->
      buffer.insertLines(0, lines)
      buffer.setTextInRange('z', [[0, 0], [0, 1]])
      expect(buffer.getLineCount()).toBe(500)
      expect(buffer.getCharacterCount()).toBe((500 * 6) - 1)
      expect(buffer.getText().length).toBe((500 * 6) - 1)
      expect(buffer.getText()[0]).toBe('z')

    it 'inserts multiple lines text in single line range', ->
      buffer.insertLines(0, lines)
      buffer.setTextInRange('one\ntwo', [[0, 0], [0, 1]])
      expect(buffer.getLineCount()).toBe(501)
      expect(buffer.getCharacterCount()).toBe(3005)
      expect(buffer.getText().length).toBe(3005)

    it 'replaces text in multi line range', ->
      buffer.insertLines(0, lines)
      buffer.setTextInRange('', [[0, 3], [4, 1]])
      expect(buffer.getLineCount()).toBe(496)
      expect(buffer.getCharacterCount()).toBe(2977)
      expect(buffer.getText().length).toBe(2977)

    it 'iterate over all characters', ->
      buffer.insertLines(0, lines)
      for i in [0...buffer.getCharacterCount()]
        expect(buffer.getLineRowColumn(i).line.getText()).toBe('12345')

  describe 'Lines', ->

    it 'inserts lines', ->
      buffer.insertLines(0, lines)
      expect(buffer.getLineCount()).toBe(500)
      expect(buffer.getCharacterCount()).toBe((500 * 6) - 1)
      expect(buffer.getText().length).toBe((500 * 6) - 1)
      expect(buffer.children.length).toBe(3)
      expect(buffer.children[0].children.length).toBe(9)
      expect(buffer.children[1].children.length).toBe(5)
      expect(buffer.children[2].children.length).toBe(5)

    it 'inserts lines at end', ->
      buffer.insertLines(0, [new Line('12345', 5)])
      buffer.insertLines(1, [new Line('12345', 5)])
      buffer.insertLines(2, [new Line('12345', 5)])
      expect(buffer.getText()).toEqual('12345\n12345\n12345')

    it 'removes lines', ->
      buffer.insertLines(0, lines)
      buffer.removeLines(0, 2)
      expect(buffer.getLineCount()).toBe(498)
      expect(buffer.getCharacterCount()).toBe((498 * 6) - 1)
      expect(buffer.getText().length).toBe((498 * 6) - 1)
      buffer.removeLines(200, 60)
      expect(buffer.getLineCount()).toBe(438)
      expect(buffer.getCharacterCount()).toBe((438 * 6) - 1)
      expect(buffer.getText().length).toBe((438 * 6) - 1)
      expect(buffer.children.length).toBe(3)
      expect(buffer.children[0].children.length).toBe(8)
      expect(buffer.children[1].children.length).toBe(5)
      expect(buffer.children[2].children.length).toBe(5)
      buffer.removeLines(0, 438)
      expect(buffer.children.length).toBe(1)
      expect(buffer.children[0].children.length).toBe(0)

    it 'remove lines at end', ->
      buffer.insertLines(0, [new Line('12345', 5)])
      buffer.insertLines(1, [new Line('12345', 5)])
      buffer.insertLines(2, [new Line('12345', 5)])
      buffer.removeLines(2, 1)
      expect(buffer.getText()).toEqual('12345\n12345')
      buffer.removeLines(0, 1)
      expect(buffer.getText()).toEqual('12345')
      buffer.removeLines(0, 1)
      expect(buffer.getText()).toEqual('')

    it 'updates line character counts', ->
      buffer.insertLines(0, lines)
      lines[0].setTextInRange('', 0, 5) # -5
      lines[241].setTextInRange('12345', 5, 5) # +5
      expect(buffer.getText().length).toBe((500 * 6) - 1)
      expect(buffer.getCharacterCount()).toBe((500 * 6) - 1)

    it 'iterates over lines', ->
      buffer.insertLines(0, lines)

      index = 0
      count = 0
      length = 499
      buffer.iterateLines index, length, (each) ->
        expect(each).toEqual(lines[index])
        index++
        count++
      expect(count).toBe(499)

      index = 365
      count = 0
      length = 100
      buffer.iterateLines index, length, (each) ->
        expect(each).toEqual(lines[index])
        index++
        count++
      expect(count).toBe(100)

      for i in [0...buffer.getLineCount()]
        expect(buffer.getLine(i).getText()).toBe('12345')

    it 'gets line at row', ->
      buffer.insertLines(0, lines)
      expect(buffer.getLine(0)).toEqual(lines[0])
      expect(buffer.getLine(1)).toEqual(lines[1])
      expect(buffer.getLine(312)).toEqual(lines[312])
      expect(buffer.getLine(499)).toEqual(lines[499])

    it 'gets row from line', ->
      buffer.insertLines(0, lines)
      expect(lines[0].getRow()).toEqual(0)
      expect(lines[1].getRow()).toEqual(1)
      expect(lines[50].getRow()).toEqual(50)
      expect(lines[51].getRow()).toEqual(51)
      expect(lines[253].getRow()).toEqual(253)
      expect(lines[499].getRow()).toEqual(499)

    it 'gets character offset from line', ->
      buffer.insertLines(0, lines)
      expect(lines[0].getCharacterOffset()).toEqual(0)
      expect(lines[1].getCharacterOffset()).toEqual(6)
      expect(lines[50].getCharacterOffset()).toEqual(300)
      expect(lines[51].getCharacterOffset()).toEqual(306)
      expect(lines[253].getCharacterOffset()).toEqual(1518)
      expect(lines[499].getCharacterOffset()).toEqual(2994)

    it 'gets line character offset at global character offset', ->
      buffer.insertLines(0, lines)
      expect(buffer.getLineRowColumn(0)).toEqual({line: lines[0], row: 0, column: 0})
      expect(buffer.getLineRowColumn(3)).toEqual({line: lines[0], row: 0, column: 3})
      expect(buffer.getLineRowColumn(5)).toEqual({line: lines[0], row: 0, column: 5})
      expect(buffer.getLineRowColumn(6)).toEqual({line: lines[1], row: 1, column: 0})
      expect(buffer.getLineRowColumn(7)).toEqual({line: lines[1], row: 1, column: 1})
      expect(buffer.getLineRowColumn(11)).toEqual({line: lines[1], row: 1, column: 5})
      expect(buffer.getLineRowColumn(12)).toEqual({line: lines[2], row: 2, column: 0})
      expect(buffer.getLineRowColumn(buffer.getCharacterCount() - 6)).toEqual({line: lines[498], row: 498, column: 5})
      expect(buffer.getLineRowColumn(buffer.getCharacterCount() - 1)).toEqual({line: lines[499], row: 499, column: 4})
      expect(buffer.getLineRowColumn(buffer.getCharacterCount())).toEqual({line: lines[499], row: 499, column: 5})

  describe 'Events', ->

    [subscriptions] = []

    beforeEach ->
      subscriptions = new CompositeDisposable

    afterEach ->
      subscriptions.dispose()

    it 'posts change events when setting text in range', ->
      buffer.insertLines(0, lines)
      subscriptions.add buffer.onDidChange (e) ->
        expect(e.oldText).toEqual('12')
        expect(e.oldRange.toString()).toEqual('[(0, 0) - (0, 2)]')
        expect(e.oldCharacterRange).toEqual(start: 0, end: 2)
        expect(e.newText).toEqual('one\ntwo')
        expect(e.newRange.toString()).toEqual('[(0, 0) - (1, 3)]')
        expect(e.newCharacterRange).toEqual(start: 0, end: 7)
      buffer.setTextInRange('one\ntwo', [[0, 0], [0, 2]])

    it 'posts change events when inserting lines', ->
      buffer.insertLines(0, lines)
      lines = [new Line('hello', 5)]
      subscriptions.add buffer.onDidChange (e) ->
        expect(e.oldText).toEqual('')
        expect(e.oldRange.toString()).toEqual('[(3, 0) - (3, 0)]')
        expect(e.oldCharacterRange).toEqual(start: 18, end: 18)
        expect(e.newText).toEqual('hello\n')
        expect(e.newRange.toString()).toEqual('[(3, 0) - (4, 0)]')
        expect(e.newCharacterRange).toEqual(start: 18, end: 24)
      buffer.insertLines(3, lines)

    it 'posts change events when removing lines', ->
      buffer.insertLines(0, lines)
      subscriptions.add buffer.onDidChange (e) ->
        expect(e.oldText).toEqual('12345\n12345\n')
        expect(e.oldRange.toString()).toEqual('[(3, 0) - (5, 0)]')
        expect(e.oldCharacterRange).toEqual(start: 18, end: 30)
        expect(e.newText).toEqual('')
        expect(e.newRange.toString()).toEqual('[(3, 0) - (3, 0)]')
        expect(e.newCharacterRange).toEqual(start: 18, end: 18)
      buffer.removeLines(3, 2)