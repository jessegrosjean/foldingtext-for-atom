SpanIndex = require '../span-index'
Line = require './Line'

class LineIndex extends SpanIndex

  @string: null

  constructor: (@string) ->
    super()

  getLineCount: ->
    @spanCount

  getLine: (index) ->
    @getSpan(index)

  getLineIndex: (child) ->
    @getSpanIndex(child)

  getLineIndexOffset: (offset, index=0) ->
    lineIndexOffset = @getSpanIndexOffset(offset, index)
    lineIndexOffset.line = lineIndexOffset.span
    lineIndexOffset

  getLines: (start, count) ->
    @getSpans(start, count)

  iterateLines: (start, count, operation) ->
    @iterateSpans(start, count, operation)

  insertLines: (start, lines) ->
    @insertSpans(start, lines)

  removeLines: (start, deleteCount) ->
    @removeSpans(start, deleteCount)

  createLineWithText: (text) ->
    @createSpanWithText(text)

  createSpanWithText: (text) ->
    new Line(text)

  deleteRange: (offset, length) ->
    unless length
      return

    super(offset, length)

    # Merge lines not sperated by \n
    if offset isnt 0
      prev = @getLineIndexOffset(offset - 1)
      prevLine = prev.line
      prevStart = prev.startOffset
      prevLength = prevLine.getLength()
      prevLineText = @string.substr(prevStart, prevLength)

      if prevLineText.indexOf('\n') is -1
        cur = @getLineIndexOffset(offset)
        prevLine.setLength(prevLine.getLength() + cur.line.getLength())
        @removeLines(cur.index, 1)

  insertText: (offset, text) ->
    unless text
      return

    super(offset, text)

    # Split line at offset for all inserted \n
    lineIndexOffset = @getLineIndexOffset(offset)
    isLastLine = lineIndexOffset.index is @getLineCount() - 1
    line = lineIndexOffset.line
    start = lineIndexOffset.startOffset
    length = line.getLength()
    lineText = @string.substr(start, length)
    lines = lineText.match(/(.+\n?)|(\n)/g)

    if lines.length > 1
      line.setLength(lines[0].length)
      insertLines = []
      for i in [1...lines.length]
        insertLines.push(@createLineWithText(lines[i].length))
      if isLastLine and lineText[lineText.length - 1] is '\n'
        insertLines.push(@createLineWithText(''))
      @insertLines(lineIndexOffset.index + 1, insertLines)

module.exports = LineIndex