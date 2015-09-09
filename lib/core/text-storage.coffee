LineIndex = require './line-index'
RunIndex = require './run-index'
_ = require 'underscore-plus'
{Emitter} = require 'atom'
Rope = require './rope'

class TextStorage

  rope: null
  runIndex: null
  lineIndex: null
  emitter: null

  constructor: (text='') ->
    if text instanceof TextStorage
      @rope = text.getString()
      @runIndex = text.runIndex?.clone()
    else
      @rope = text

  clone: ->
    clone = new TextStorage(@string)
    clone.runIndex = @runIndex?.clone()
    clone.lineIndex = @lineIndex?.clone()
    clone

  destroy: ->
    unless @destroyed
      @destroyed = true
      @runIndex?.destroy()
      @lineIndex?.destroy()
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
  String
  ###

  getString: ->
    @rope.toString()

  getLength: ->
    @rope.length

  string: null
  Object.defineProperty @::, 'string',
    get: -> @rope.toString()

  length: null
  Object.defineProperty @::, 'length',
    get: -> @rope.length

  substring: (start, end) ->
    @rope.substring(start, end)

  substr: (start, length) ->
    @rope.substr(start, length)

  charAt: (position) ->
    @rope.charAt(position)

  charCodeAt: (position) ->
    @rope.charCodeAt(position)

  deleteRange: (location, length) ->
    unless length
      return
    @replaceRangeWithText(location, length, '')

  insertText: (location, text) ->
    unless text.length
      return
    @replaceRangeWithText(location, 0, text)

  appendText: (text) ->
    @insertText(@rope.length, text)

  replaceRangeWithText: (location, length, text) ->
    if text instanceof TextStorage
      insertString = text.string
      textRunIndex = text._getRunIndex()
    else
      insertString = text

    insertString = insertString.split(/\u000d(?:\u000a)?|\u000a|\u2029|\u000c|\u0085/).join('\n')

    if @rope instanceof Rope
      @rope.replace(location, length, insertString)
    else
      if @length + length > Rope.SPLIT_LENGTH
        @rope = new Rope(@rope)
        @rope.replace(location, length, insertString)
      else
        @rope = @rope.substr(0, location) + insertString + @rope.substr(location + length)

    @runIndex?.replaceRange(location, length, insertString)
    @lineIndex?.replaceRange(location, length, insertString)

    if textRunIndex and text.length
      @setAttributesInRange({}, location, text.length)
      insertRuns = []
      textRunIndex.iterateRuns 0, textRunIndex.getRunCount(), (run) ->
        insertRuns.push(run.clone())
      @_getRunIndex().replaceSpansFromLocation(location, insertRuns)

  ###
  Attributes
  ###

  _getRunIndex: ->
    unless runIndex = @runIndex
      @runIndex = runIndex = new RunIndex
      @runIndex.insertString(0, @rope.toString())
    runIndex

  getRuns: ->
    if @runIndex
      @runIndex.getRuns()
    else
      []

  getAttributesAtIndex: (index, effectiveRange, longestEffectiveRange) ->
    if index >= @length
      throw new Error("Invalide character index: #{characterIndex}")
    if @runIndex
      @runIndex.getAttributesAtIndex(index, effectiveRange, longestEffectiveRange)
    else
      if effectiveRange
        effectiveRange.location = 0
        effectiveRange.length = @length
      if longestEffectiveRange
        longestEffectiveRange.location = 0
        longestEffectiveRange.length = @length
      {}

  getAttributeAtIndex: (attribute, index, effectiveRange, longestEffectiveRange) ->
    if index >= @length
      throw new Error("Invalide character index: #{characterIndex}")
    if @runIndex
      @runIndex.getAttributeAtIndex(attribute, index, effectiveRange, longestEffectiveRange)
    else
      if effectiveRange
        effectiveRange.location = 0
        effectiveRange.length = @length
      if longestEffectiveRange
        longestEffectiveRange.location = 0
        longestEffectiveRange.length = @length
      undefined

  setAttributesInRange: (attributes, index, length) ->
    if @runIndex and not _.isEmpty(attributes)
      @runIndex.setAttributesInRange(attributes, index, length)

  addAttributeInRange: (attribute, value, index, length) ->
    @_getRunIndex().addAttributeInRange(attribute, value, index, length)

  addAttributesInRange: (attributes, index, length) ->
    @_getRunIndex().addAttributesInRange(attributes, index, length)

  removeAttributeInRange: (attribute, index, length) ->
    if @runIndex
      @runIndex.removeAttributeInRange(attribute, index, length)

  ###
  String and attributes
  ###

  subtextStorage: (location, length) ->
    unless length
      return new TextStorage('')
    subtextStorage = new TextStorage(@rope.substr(location, length))
    if @runIndex
      slice = @runIndex.sliceSpansToRange(location, length)
      insertRuns = []
      @runIndex.iterateRuns slice.spanIndex, slice.count, (run) ->
        insertRuns.push(run.clone())
      subtextStorage._getRunIndex().replaceSpansFromLocation(0, insertRuns)
    subtextStorage

  ###
  Lines
  ###

  _getLineIndex: ->
    unless lineIndex = @lineIndex
      @lineIndex = lineIndex = new LineIndex
      @lineIndex.insertString(0, @rope.toString())
    lineIndex

  getLineCount: ->
    @_getLineIndex().getLineCount()

  getLine: (row) ->
    @_getLineIndex().getLine(row)

  getRow: (line) ->
    @_getLineIndex().getLineIndex(line)

  getLines: (row, count) ->
    @_getLineIndex().getLines(row, count)

  iterateLines: (row, count, operation) ->
    @_getLineIndex().iterateLines(row, count, operation)

  ###
  Debug
  ###

  toString: ->
    "lines: #{@_getLineIndex().toString()} runs: #{@_getRunIndex().toString()}"

module.exports = TextStorage
