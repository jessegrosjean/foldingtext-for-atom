SpanIndex = require '../span-index'
LineSpan = require './line-span'

class LineIndex extends SpanIndex

  constructor: (children) ->
    super(children)
    @lastSpan = null

  getLineCount: ->
    @spanCount

  getLine: (index) ->
    @getSpan(index)

  getLineIndex: (child) ->
    @getSpanIndex(child)

  getLines: (start, count) ->
    @getSpans(start, count)

  iterateLines: (start, count, operation) ->
    @iterateSpans(start, count, operation)

  insertLines: (start, lines) ->
    @insertSpans(start, lines)

  removeLines: (start, deleteCount) ->
    @removeSpans(start, deleteCount)

  createLine: (text) ->
    @createSpan(text)

  createSpan: (text) ->
    new LineSpan(text)

  deleteRange: (location, length) ->
    unless length
      return

    start = @getSpanInfoAtLocation(location, true)
    end = @getSpanInfoAtLocation(location + length, true)

    if start.span is end.span
      start.span.deleteRange(start.location, end.location - start.location)
    else
      trail = end.span.getLineContent().substr(end.location)
      start.span.deleteRange(start.location, start.span.getLineContent().length - start.location)
      start.span.insertString(start.span.getLineContent().length, trail)
      @removeSpans(start.spanIndex + 1, end.spanIndex - start.spanIndex)

  insertString: (location, text) ->
    unless text
      return

    if @getSpanCount() is 0
      @insertSpans(0, [@createSpan('')])

    start = @getSpanInfoAtLocation(location, true)
    lines = text.split('\n')

    if lines.length is 1
      start.span.insertString(start.location, lines[0])
    else
      insertingAtEnd = start.spanIndex is @getSpanCount() - 1
      leed = lines.shift()
      trail = start.span.getLineContent().substr(start.location)
      lastLine = lines.pop() + trail
      start.span.deleteRange(start.location, start.span.getLength() - start.location)
      start.span.insertString(start.location, leed)
      spans = (@createSpan(each) for each in lines)
      spans.push(@createSpan(lastLine))

      @insertSpans(start.spanIndex + 1, spans)

  insertSpans: (spanIndex, spans) ->
    isAtEnd = spanIndex is @getSpanCount()

    if isAtEnd
      if oldLast = @getSpan(spanIndex - 1)
        oldLast.setIsLast(false)

    super(spanIndex, spans)

    if isAtEnd
      if newLast = @getSpan(spanIndex + spans.length - 1)
        newLast.setIsLast(true)

  removeSpans: (spanIndex, deleteCount) ->
    end = spanIndex + deleteCount
    isAtEnd = end is @getSpanCount()

    if isAtEnd
      if oldLast = @getSpan(end - 1)
        oldLast.setIsLast(false)

    super(spanIndex, deleteCount)

    if isAtEnd
      if newLast = @getSpan(spanIndex - 1)
        newLast.setIsLast(true)

module.exports = LineIndex