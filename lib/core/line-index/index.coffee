SpanIndex = require '../span-index'
Line = require './Line'

class LineIndex extends SpanIndex

  @stringStore: null

  constructor: (@stringStore) ->
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

  deleteText: (offset, length) ->
    super(offset, length)

    # Merge lines not sperated by \n
    if offset isnt 0
      prev = @getLineIndexOffset(offset - 1)
      prevLine = prev.line
      prevStart = prev.startOffset
      prevLength = prevLine.getLength()
      prevLineText = @stringStore.substr(prevStart, prevLength)

      if prevLineText.indexOf('\n') is -1
        cur = @getLineIndexOffset(offset)
        prevLine.setLength(prevLine.getLength() + cur.line.getLength())
        @removeLines(cur.index, 1)

  insertText: (offset, text) ->
    super(offset, text)

    # Split line at offset for all inserted \n
    lineIndexOffset = @getLineIndexOffset(offset)
    line = lineIndexOffset.line
    start = lineIndexOffset.startOffset
    length = line.getLength()
    lineText = @stringStore.substr(start, length)
    lineStart = 0
    lineEnd = lineText.indexOf('\n', lineStart) + 1

    if lineEnd > 0
      lineStart = lineEnd
      lineEnd = lineText.indexOf('\n', lineStart) + 1

      if lineEnd > 0
        line.setLength(line.getLength() - lineStart)
        insertLines = []
        while lineEnd > 0
          insertLines.push(@createLineWithText(lineEnd - lineStart))
          lineStart = lineEnd
          lineEnd = lineText.indexOf('\n', lineStart) + 1
        insertLines.push(@createLineWithText(lineStart - lineText.length))
        @insertLines(lineIndexOffset.index + 1, insertLines)

module.exports = LineIndex