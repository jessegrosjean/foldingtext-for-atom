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

  getLineIndexOffset: (offset, index=0) ->
    lineIndexOffset = @getSpanAtOffset(offset, index)
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

  createLine: (text) ->
    @createSpan(text)

  createSpan: (text) ->
    new Line(text)

  deleteRange: (offset, length) ->
    unless length
      return

    slice = @sliceSpansToRange(offset, length)
    if length is @getLength()
      @getSpan(0).setString('')
      @removeSpans(slice.index + 1, slice.count - 1)
    else
      @removeSpans(slice.index, slice.count)

    cur = @getSpanAtOffset(offset)
    if cur.span.getString().indexOf('\n') is -1
      if next = @getSpan(cur.index + 1)
        cur.span.appendString(next.getString())
        @removeSpans(cur.index + 1, 1)

  insertString: (offset, text) ->
    unless text
      return

    if @getSpanCount() is 0
      @insertSpans(0, [@createSpan('')])

    start = @getSpanAtOffset(offset)
    if start.offset is start.span.getLength()
      if offset is @getLength()
        if next = @getSpan(start.index + 1)
          start.span = next
          start.offset = 0
          start.index++
      else
        start = @getSpanAtOffset(offset + 1)
        start.offset = 0

    lines = text.split('\n')
    trail = start.span.getString().substr(start.offset)
    start.span.deleteRange(start.offset, start.span.getLength() - start.offset)
    start.span.insertString(start.offset, lines.shift())

    if start.index isnt @getSpanCount() - 1 and start.span.getString().indexOf('\n') is -1
      start.span.appendString('\n')

    if lines.length
      lines[lines.length - 1] += trail
      spans = (@createSpan(each) for each in lines)
      @insertSpans(start.index + 1, spans)

  insertSpans: (start, spans) ->
    for each in spans
      if each.getString().indexOf('\n') is -1
        each.appendString('\n')

    if start is @getSpanCount()
      if oldLast = @getSpan(start - 1)
        if oldLast.getString().indexOf('\n') is -1
          oldLast.appendString('\n')
      newLast = spans[spans.length - 1]
      newLast.deleteRange(newLast.getLength() - 1, 1)

    super(start, spans)

  removeSpans: (start, deleteCount) ->
    super(start, deleteCount)

    if start is @getSpanCount()
      if newLast = @getSpan(start - 1)
        if newLast.getString().indexOf('\n') isnt -1
          newLast.deleteRange(newLast.getLength() - 1, 1)

module.exports = LineIndex