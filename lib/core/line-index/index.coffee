SpanIndex = require '../span-index'
Line = require './Line'

class LineIndex extends SpanIndex

  constructor: (string) ->
    super(string)

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
    new Line(text)

  deleteRange: (location, length) ->
    unless length
      return

    slice = @sliceSpansToRange(location, length)
    if length is @getLength()
      @getSpan(0).setString('')
      @removeSpans(slice.spanIndex + 1, slice.count - 1)
    else
      @removeSpans(slice.spanIndex, slice.count)

    cur = @getSpanInfoAtLocation(location)
    if cur.span.getString().indexOf('\n') is -1
      if next = @getSpan(cur.spanIndex + 1)
        cur.span.appendString(next.getString())
        @removeSpans(cur.spanIndex + 1, 1)

  insertString: (location, text) ->
    unless text
      return

    if @getSpanCount() is 0
      @insertSpans(0, [@createSpan('')])

    start = @getSpanInfoAtLocation(location, true)
    lines = text.split('\n')
    trail = start.span.getString().substr(start.location)
    start.span.deleteRange(start.location, start.span.getLength() - start.location)
    start.span.insertString(start.location, lines.shift())

    if start.spanIndex isnt @getSpanCount() - 1 and start.span.getString().indexOf('\n') is -1
      start.span.appendString('\n')

    if lines.length
      lines[lines.length - 1] += trail
      spans = (@createSpan(each) for each in lines)
      @insertSpans(start.spanIndex + 1, spans)

  insertSpans: (spanIndex, spans) ->
    for each in spans
      if each.getString().indexOf('\n') is -1
        each.appendString('\n')

    if spanIndex is @getSpanCount()
      if oldLast = @getSpan(spanIndex - 1)
        if oldLast.getString().indexOf('\n') is -1
          oldLast.appendString('\n')
      newLast = spans[spans.length - 1]
      newLast.deleteRange(newLast.getLength() - 1, 1)

    super(spanIndex, spans)

  removeSpans: (spanIndex, deleteCount) ->
    super(spanIndex, deleteCount)

    if spanIndex is @getSpanCount()
      if newLast = @getSpan(spanIndex - 1)
        if newLast.getString().indexOf('\n') isnt -1
          newLast.deleteRange(newLast.getLength() - 1, 1)

module.exports = LineIndex