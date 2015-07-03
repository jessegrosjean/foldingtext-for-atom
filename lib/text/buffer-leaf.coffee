Range = require './range'
Mark = require './mark'

class BufferLeaf

  marks: null

  constructor: (@children) ->
    @parent = null
    characterCount = 0
    for each in @children
      each.parent = this
      characterCount += each.getCharacterCount()
    @characterCount = characterCount

  ###
  Section: Lines
  ###

  getLineCount: ->
    @children.length

  getCharacterCount: ->
    @characterCount

  getLine: (row) ->
    @children[row]

  getRow: (child) ->
    row = @parent?.getRow(this) or 0
    if child
      row += @children.indexOf(child)
    row

  getCharacterOffset: (child) ->
    characterOffset = @parent?.getCharacterOffset(this) or 0
    if child
      for each in @children
        if each is child
          break
        characterOffset += each.getCharacterCount()
    characterOffset

  getLineRowColumn: (characterOffset, row=0) ->
    for each in @children
      childCharacterCount = each.getCharacterCount()
      if characterOffset >= childCharacterCount
        characterOffset -= childCharacterCount
        row++
      else
        return {} =
          line: each
          row: row
          column: characterOffset

  iterateLines: (start, count, operation) ->
    for i in [start...start + count]
      operation(@children[i])

  insertLines: (index, lines) ->
    for each in lines
      each.parent = this
      @characterCount += each.getCharacterCount()
    @children = @children.slice(0, index).concat(lines).concat(@children.slice(index))

    if @marks
      for each in @marks
        each.insertedLines(index, index + lines.length)

  removeLines: (start, deleteCount) ->
    end = start + deleteCount
    for i in [start...end]
      each = @children[i]
      each.parent = null
      @characterCount -= each.getCharacterCount()
    @children.splice(start, deleteCount)

    if @marks
      for each in @marks
        each.deletedLines(start, end)

  ###
  Section: Marks
  ###

  markRange: (range, properties) ->
    if range.isSingleLine()
      line = @children[range.start.row]
      line.markRange(range.start.column, range.end.column, properties)
    else
      new Mark(this, range, properties)

  _getMarksRange: (mark) ->
    row = @getRow()
    range = mark.range
    new Range([row + range.start.row, range.start.column], [row + range.end.row, range.end.column])

  iterateMarks: (startLine, startColumn, endLine, endColumn, operation) ->
    if start is end
      line.iterateMarks(0, startColumn, 0, endColumn, operation)
    else
      if @marks
        for each in @marks
          operation(each)

      for i in [startLine...endLine]
        if i is startLine
          @children[i].iterateMarks(0, startColumn, 0, null, operation)
        else if i is endLine
          @children[i].iterateMarks(0, null, 0, endColumn, operation)
        else
          @children[i].iterateMarks(0, null, 0, null, operation)

  ###
  Section: Util
  ###

  collapse: (lines) ->
    @children.push.apply(lines, @children)

module.exports = BufferLeaf