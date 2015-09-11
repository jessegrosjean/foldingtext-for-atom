LineBuffer = require './line-buffer'
RunBuffer = require './run-buffer'
_ = require 'underscore-plus'
{Emitter} = require 'atom'

class AttributedString

  constructor: (text='') ->
    if text instanceof AttributedString
      @string = text.getString()
      @runBuffer = text.runBuffer?.clone()
    else
      @string = text

  clone: ->
    clone = new AttributedString(@string)
    clone.runBuffer = @runBuffer?.clone()
    clone.lineBuffer = @lineBuffer?.clone()
    clone

  ###
  String
  ###

  getString: ->
    @string.toString()

  getLength: ->
    @string.length

  length: null
  Object.defineProperty @::, 'length',
    get: -> @string.length

  substring: (start, end) ->
    @string.substring(start, end)

  substr: (start, length) ->
    @string.substr(start, length)

  charAt: (position) ->
    @string.charAt(position)

  charCodeAt: (position) ->
    @string.charCodeAt(position)

  deleteRange: (location, length) ->
    unless length
      return
    @replaceRangeWithText(location, length, '')

  insertText: (location, text) ->
    unless text.length
      return
    @replaceRangeWithText(location, 0, text)

  appendText: (text) ->
    @insertText(@string.length, text)

  replaceRangeWithText: (location, length, text) ->
    if length is -1
      length = @getLength() - location

    if text instanceof AttributedString
      insertString = text.string
      if @runBuffer
        textRunBuffer = text._getRunBuffer()
      else
        textRunBuffer = text.runBuffer
    else
      insertString = text

    insertString = insertString.split(/\u000d(?:\u000a)?|\u000a|\u2029|\u000c|\u0085/).join('\n')

    @string = @string.substr(0, location) + insertString + @string.substr(location + length)
    @runBuffer?.replaceRange(location, length, insertString)
    @lineBuffer?.replaceRange(location, length, insertString)

    if textRunBuffer and text.length
      @setAttributesInRange({}, location, text.length)
      insertRuns = []
      textRunBuffer.iterateRuns 0, textRunBuffer.getRunCount(), (run) ->
        insertRuns.push(run.clone())
      @_getRunBuffer().replaceSpansFromLocation(location, insertRuns)

  ###
  Attributes
  ###

  _getRunBuffer: ->
    unless runBuffer = @runBuffer
      @runBuffer = runBuffer = new RunBuffer
      @runBuffer.insertString(0, @string.toString())
    runBuffer

  getRuns: ->
    if @runBuffer
      @runBuffer.getRuns()
    else
      []

  getAttributesAtIndex: (index, effectiveRange, longestEffectiveRange) ->
    if index >= @length
      throw new Error("Invalide character index: #{characterIndex}")
    if @runBuffer
      @runBuffer.getAttributesAtIndex(index, effectiveRange, longestEffectiveRange)
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
    if @runBuffer
      @runBuffer.getAttributeAtIndex(attribute, index, effectiveRange, longestEffectiveRange)
    else
      if effectiveRange
        effectiveRange.location = 0
        effectiveRange.length = @length
      if longestEffectiveRange
        longestEffectiveRange.location = 0
        longestEffectiveRange.length = @length
      undefined

  setAttributesInRange: (attributes, index, length) ->
    @_getRunBuffer().setAttributesInRange(attributes, index, length)

  addAttributeInRange: (attribute, value, index, length) ->
    @_getRunBuffer().addAttributeInRange(attribute, value, index, length)

  addAttributesInRange: (attributes, index, length) ->
    @_getRunBuffer().addAttributesInRange(attributes, index, length)

  removeAttributeInRange: (attribute, index, length) ->
    if @runBuffer
      @runBuffer.removeAttributeInRange(attribute, index, length)

  ###
  String and attributes
  ###

  subattributedString: (location, length) ->
    unless length
      return new AttributedString('')

    if length is -1
      length = @getLength() - location

    subattributedString = new AttributedString(@string.substr(location, length))
    if @runBuffer
      slice = @runBuffer.sliceSpansToRange(location, length)
      insertRuns = []
      @runBuffer.iterateRuns slice.spanIndex, slice.count, (run) ->
        insertRuns.push(run.clone())
      subattributedString._getRunBuffer().replaceSpansFromLocation(0, insertRuns)
    subattributedString

  ###
  Lines
  ###

  _getLineBuffer: ->
    unless lineBuffer = @lineBuffer
      @lineBuffer = lineBuffer = new LineBuffer
      @lineBuffer.insertString(0, @string.toString())
    lineBuffer

  getLineCount: ->
    @_getLineBuffer().getLineCount()

  getLine: (row) ->
    @_getLineBuffer().getLine(row)

  getRow: (line) ->
    @_getLineBuffer().getLineBuffer(line)

  getLines: (row, count) ->
    @_getLineBuffer().getLines(row, count)

  iterateLines: (row, count, operation) ->
    @_getLineBuffer().iterateLines(row, count, operation)

  ###
  Debug
  ###

  toString: ->
    "lines: #{@_getLineBuffer().toString()} runs: #{@_getRunBuffer().toString()}"

module.exports = AttributedString
