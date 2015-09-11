SpanIndex = require '../span-index'
LineSpan = require './line-span'

class LineIndex extends SpanIndex

  constructor: (children) ->
    super(children)

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

  removeLines: (start, removeCount) ->
    @removeSpans(start, removeCount)

  createLine: (text) ->
    @createSpan(text)

  createSpan: (text) ->
    new LineSpan(text)

  replaceRange: (location, length, string) ->
    if location < 0 or (location + length) > @getLength()
      throw new Error("Invalide text range: #{location}-#{location + length}")

    if @emitter and not @changing
      changeEvent =
        location: location
        replacedLength: length
        insertedString: string
      @emitter.emit 'will-change', changeEvent

    lines = string.split('\n')

    @changing++
    if @getSpanCount() is 0
      @insertSpans(0, (@createSpan(each) for each in lines))
    else
      start = @getSpanInfoAtLocation(location, true)
      end = @getSpanInfoAtLocation(location + length, true)

      if start.span is end.span and lines.length is 1
        start.span.replaceRange(start.location, length, lines[0])
      else
        endSuffix = end.span.getLineContent().substr(end.location)
        start.span.replaceRange(start.location, start.span.getLength() - start.location, lines.shift())
        @removeSpans(start.spanIndex + 1, end.spanIndex - start.spanIndex)
        insertedLines = (@createLine(each) for each in lines)
        @insertLines(start.spanIndex + 1, insertedLines)
        if endSuffix.length
          lastLine = insertedLines[insertedLines.length - 1] ? start.span
          lastLine.appendString(endSuffix)
    @changing--

    if changeEvent
      @emitter.emit 'did-change', changeEvent

  insertSpans: (spanIndex, spans) ->
    unless spans.length
      return

    if spanIndex is @getSpanCount()
      @getSpan(spanIndex - 1)?.setIsLast(false)
      spans[spans.length - 1]?.setIsLast(true)
      super spanIndex, spans, (changeEvent) ->
        unless spanIndex is 0
          changeEvent.location--
          changeEvent.insertedString = '\n' + changeEvent.insertedString
    else
      super(spanIndex, spans)

  removeSpans: (spanIndex, removeCount) ->
    unless removeCount
      return

    removeTo = spanIndex + removeCount
    if removeTo is @getSpanCount()
      @getSpan(spanIndex - 1)?.setIsLast(true)
      @getSpan(removeTo - 1)?.setIsLast(false)
      super spanIndex, removeCount, (changeEvent) ->
        if spanIndex is 0
          changeEvent.replacedLength--
    else
      super(spanIndex, removeCount)

module.exports = LineIndex