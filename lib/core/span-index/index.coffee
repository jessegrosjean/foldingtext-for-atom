SpanBranch = require './span-branch'
SpanLeaf = require './span-leaf'
{Emitter} = require 'atom'
assert = require 'assert'
Span = require './span'

class SpanIndex extends SpanBranch

  emitter: null
  inclusiveLeft: false
  inclusiveRight: true

  constructor: (children) ->
    children ?= [new SpanLeaf([])]
    super(children)
    @changing = 0

  clone: ->
    super()

  destroy: ->
    unless @destroyed
      @destroyed = true
      @emitter?.emit 'did-destroy'

  ###
  Section: Events
  ###

  _getEmitter: ->
    unless emitter = @emitter
      @emitter = emitter = new Emitter
    emitter

  onDidBeginChanges: (callback) ->
    @_getEmitter().on 'did-begin-changes', callback

  onWillChange: (callback) ->
    @_getEmitter().on 'will-change', callback

  onDidChange: (callback) ->
    @_getEmitter().on 'did-change', callback

  onDidEndChanges: (callback) ->
    @_getEmitter().on 'did-end-changes', callback

  onDidDestroy: (callback) ->
    @_getEmitter().on 'did-destroy', callback

  ###
  Section: Characters
  ###

  deleteRange: (offset, length) ->
    unless length
      return

    slice = @sliceSpansToRange(offset, length)
    @removeSpans(slice.index, slice.count)

  insertString: (offset, string) ->
    unless string
      return

    if @getSpanCount() is 0
      @insertSpans(0, [@createSpan(string)])
    else
      start = @getSpanAtOffset(offset)
      start.span.insertString(start.offset, string)

  replaceRange: (offset, length, string) ->
    @insertString(offset, string)
    @deleteRange(offset + string.length, length)

  ###
  Section: Spans
  ###

  createSpan: (text) ->
    new Span(text)

  getSpanAtOffset: (offset, index=0) ->
    result = super(offset, index)
    result.startOffset = offset - result.offset
    result

  sliceSpanAtOffset: (offset) ->
    start = @getSpanAtOffset(offset)
    if startSplit = start.span.split(start.offset)
      @insertSpans(start.index + 1, [startSplit])
    start

  sliceSpansToRange: (offset, length) ->
    assert(length > 0)
    start = @sliceSpanAtOffset(offset)
    if start.offset is start.span.getLength()
      start.index++
    end = @sliceSpanAtOffset(offset + length)
    {} =
      index: start.index
      count: (end.index - start.index) + 1

  replaceSpansFromOffset: (offset, spans) ->
    totalLength = 0
    for each in spans
      totalLength += each.getLength()
    slice = @sliceSpansToRange(offset, totalLength)
    @removeSpans(slice.index, slice.count)
    @insertSpans(slice.index, spans)

  ###
  Section: Debug
  ###

  toString: ->
    spanStrings = []
    @iterateSpans 0, @getSpanCount(), (span) ->
      spanStrings.push(span.toString())
    "#{spanStrings.join('')}"

module.exports = SpanIndex