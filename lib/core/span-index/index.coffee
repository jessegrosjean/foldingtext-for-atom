SpanBranch = require './span-branch'
SpanLeaf = require './span-leaf'
{Emitter} = require 'atom'
assert = require 'assert'
Span = require './span'

class SpanIndex extends SpanBranch

  emitter: null

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

  deleteRange: (location, length) ->
    unless length
      return

    slice = @sliceSpansToRange(location, length)
    @removeSpans(slice.spanIndex, slice.count)

  insertString: (location, string) ->
    unless string
      return

    if @getSpanCount() is 0
      @insertSpans(0, [@createSpan(string)])
    else
      start = @getSpanInfoAtLocation(location)
      start.span.insertString(start.location, string)

  replaceRange: (location, length, string) ->
    @insertString(location, string)
    @deleteRange(location + string.length, length)

  ###
  Section: Spans
  ###

  createSpan: (text) ->
    new Span(text)

  getSpanInfoAtCharacterIndex: (characterIndex) ->
    if characterIndex < @getLength()
      @getSpanInfoAtLocation(characterIndex, true)
    else
      throw new Error("Invalide character index: #{characterIndex}")

  getSpanInfoAtLocation: (location, chooseRight=false) ->
    if location > @getLength()
      throw new Error("Invalide cursor location: #{location}")
    if chooseRight
      if location is @getLength()
        lastSpanIndex = @getSpanCount() - 1
        lastSpan = @getSpan(lastSpanIndex)
        spanInfo =
          span: lastSpan
          spanIndex: lastSpanIndex
          location: lastSpan.getLength()
          spanLocation: location - lastSpan.getLength()
      else
        spanInfo = super(location + 1)
        spanInfo.location--
    else
      spanInfo = super(location)
    spanInfo

  sliceSpanAtLocation: (location) ->
    start = @getSpanInfoAtLocation(location)
    if startSplit = start.span.split(start.location)
      @insertSpans(start.spanIndex + 1, [startSplit])
    start

  sliceSpansToRange: (location, length) ->
    assert(length > 0)
    start = @sliceSpanAtLocation(location)
    if start.location is start.span.getLength()
      start.spanIndex++
    end = @sliceSpanAtLocation(location + length)
    {} =
      spanIndex: start.spanIndex
      count: (end.spanIndex - start.spanIndex) + 1

  replaceSpansFromLocation: (location, spans) ->
    totalLength = 0
    for each in spans
      totalLength += each.getLength()
    slice = @sliceSpansToRange(location, totalLength)
    @removeSpans(slice.spanIndex, slice.count)
    @insertSpans(slice.spanIndex, spans)

  ###
  Section: Debug
  ###

  toString: ->
    spanStrings = []
    @iterateSpans 0, @getSpanCount(), (span) ->
      spanStrings.push(span.toString())
    "#{spanStrings.join('')}"

module.exports = SpanIndex