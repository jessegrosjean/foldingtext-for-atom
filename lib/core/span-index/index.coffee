SpanBranch = require './span-branch'
SpanLeaf = require './span-leaf'
{Emitter} = require 'atom'
Span = require './span'

class SpanIndex extends SpanBranch

  constructor: ->
    super([new SpanLeaf([])])
    @changing = 0
    @emitter = new Emitter()

  destroy: ->
    unless @destroyed
      @destroyed = true
      @emitter.emit 'did-destroy'

  ###
  Section: Events
  ###

  onDidBeginChanges: (callback) ->
    @emitter.on 'did-begin-changes', callback

  onWillChange: (callback) ->
    @emitter.on 'will-change', callback

  onDidChange: (callback) ->
    @emitter.on 'did-change', callback

  onDidEndChanges: (callback) ->
    @emitter.on 'did-end-changes', callback

  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  ###
  Section: Characters
  ###

  deleteText: (offset, length) ->
    unless length
      return

    start = @getSpanIndexOffset(offset)
    end = @getSpanIndexOffset(offset + length)

    if start.span is end.span
      if start.offset is 0 and start.span.getLength() is length
        @removeSpans(start.index, 1)
      else
        start.span.deleteText(start.offset, end.offset - start.offset)
    else
      removeStart = start.index
      removeLength = end.index - start.index
      unless start.offset is 0
        start.span.deleteText(start.offset, start.span.getLength() - start.offset)
        removeStart++
        removeLength--
      unless end.offset is end.span.getLength()
        end.span.deleteText(0, end.offset)
        removeLength--

      if removeLength > 0
        @removeSpans(removeStart, removeLength)

    if @getSpanCount() is 0 and start
      start.span.deleteText(0, start.span.getLength())
      @insertSpans(0, [start.span])

  insertText: (offset, text) ->
    if text
      if @getSpanCount() is 0
        @insertSpans(0, [@createSpanWithText(text)])
      else
        start = @getSpanIndexOffset(offset)
        start.span.insertText(start.offset, text)

  ###
  Section: Spans
  ###

  createSpanWithText: (text) ->
    new Span(text)

  getSpanIndexOffset: (offset, index=0) ->
    # Special case offset = length
    if offset is @getLength()
      spanCount = @getSpanCount()
      span = @getSpan(spanCount - 1)
      {} =
        span: span
        index: spanCount - 1
        startOffset: offset - span.getLength()
        offset: span.getLength()
    else
      result = super(offset, index)
      result.startOffset = offset - result.offset
      result

  ###
  Section: Debug
  ###

  toString: ->
    toStrings = []
    @iterateSpans 0, @getSpanCount(), (span) ->
      toStrings.push(span.toString())
    "length: #{@getLength()} spans: #{toStrings.join(', ')}"

module.exports = SpanIndex