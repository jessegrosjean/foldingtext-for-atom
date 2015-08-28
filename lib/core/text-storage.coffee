LineIndex = require './line-index'
RunIndex = require './run-index'
{Emitter} = require 'atom'
Rope = require './rope'

class TextStorage

  string: null
  runIndex: null
  lineIndex: null
  emitter: null

  constructor: (string='') ->
    @string = string

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
    @string.toString()

  getLength: ->
    @string.length

  substring: (start, end) ->
    @string.substring(start, end)

  substr: (start, length) ->
    @string.substring(start, length)

  charAt: (position) ->
    @string.charAt(position)

  charCodeAt: (position) ->
    @string.charCodeAt(position)

  deleteRange: (offset, length) ->
    unless length
      return
    unless @string.remove
      @string = new Rope(@string)
      @lineIndex?.string = @string
    @string.remove(offset, offset + length)
    @runIndex?.deleteRange(offset, length)
    @lineIndex?.deleteRange(offset, length)

  insertString: (offset, text) ->
    text = text.split(/\u000d(?:\u000a)?|\u000a|\u2029|\u000c|\u0085/).join('\n')

    unless @string.insert
      @string = new Rope(@string)
      @lineIndex?.string = @string
    @string.insert(offset, text)
    @runIndex?.insertText(offset, text)
    @lineIndex?.insertText(offset, text)

  replaceRangeWithString: (offset, length, string) ->
    @deleteRange(offset, length)
    @insertString(offset, string)

  ###
  Attributes
  ###

  attributesAtOffset: (offset, effectiveRange, longestEffectiveRange) ->
    if @runIndex
      @runIndex.attributesAtOffset(offset, effectiveRange, longestEffectiveRange)
    else
      @runIndex.createRunWithText(@string.length)

  attributeAtOffset: (attribute, offset, effectiveRange, longestEffectiveRange) ->
    if @runIndex
      @runIndex.attributeAtOffset(attribute, offset, effectiveRange, longestEffectiveRange)
    else
      @runIndex.createRunWithText(@string.length)

  _getRunIndex: ->
    unless runIndex = @runIndex
      @runIndex = runIndex = new RunIndex
      @runIndex.insertText(0, @string.length)
    runIndex

  setAttributesInRange: (attributes, offset, length) ->
    @_getRunIndex().setAttributesInRange(attributes, offset, length)

  addAttributeInRange: (attribute, value, offset, length) ->
    @_getRunIndex().addAttributeInRange(attribute, value, offset, length)

  addAttributesInRange: (attributes, offset, length) ->
    @_getRunIndex().addAttributesInRange(attributes, offset, length)

  removeAttributeInRange: (attribute, offset, length) ->
    if @runIndex
      @runIndex.removeAttributeInRange(attribute, offset, length)

  ###
  String and attributes
  ###

  subtextStorage: (offset, length) ->
    subtextStorage = new TextStorage(@string.substr(offset, length))
    if @runIndex
      slice = @runIndex.sliceSpansToRange(offset, length)
      insertRuns = []
      @runIndex.iterateRuns slice.startIndex, slice.count, (run) ->
        insertRuns.push(run.clone())
    subtextStorage._getRunIndex().replaceSpansFromOffset(0, insertRuns)
    subtextStorage

  appendTextStorage: (textStorage) ->
    @insertTextStorage(@string.length, textStorage)

  insertTextStorage: (offset, textStorage) ->
    @insertString(offset, textStorage.getString())
    @setAttributesInRange({}, offset, textStorage.getLength())
    if otherRunIndex = textStorage.runIndex
      insertRuns = []
      otherRunIndex.iterateRuns 0, otherRunIndex.getRunCount(), (run) ->
        insertRuns.push(run.clone())
      @_getRunIndex().replaceSpansFromOffset(offset, insertRuns)

  replaceRangeWithTextStorage: (offset, length, textStorage) ->
    @deleteRange(offset, length)
    @insertTextStorage(offset, textStorage)

  ###
  Lines
  ###

  _getLineIndex: ->
    unless lineIndex = @lineIndex
      @lineIndex = lineIndex = new LineIndex
      @lineIndex.string = @string
      @lineIndex.insertText(0, @string.toString())
    lineIndex

  getLineCount: ->
    @_getLineIndex().getLineCount()

  getLine: (row) ->
    @_getLineIndex().getLine(row)

  getRow: (line) ->
    @_getLineIndex().getLineIndex(line)

  getLineRowOffset: (offset) ->
    @_getLineIndex().getLineIndexOffset(offset)

  getLines: (row, count) ->
    @_getLineIndex().getLines(row, count)

  iterateLines: (row, count, operation) ->
    @_getLineIndex().iterateLines(row, count, operation)

  ###
  Debug
  ###

  toString: ->
    "[string: #{@getString()}] [lines: #{@_getLineIndex().toString()}] [runs: #{@_getRunIndex().toString()}]"

module.exports = TextStorage
