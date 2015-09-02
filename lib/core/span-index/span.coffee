_ = require 'underscore-plus'

class Span

  @parent: null
  @string: ''

  constructor: (@string='') ->

  clone: ->
    new @constructor(@string)

  split: (offset) ->
    if offset is 0 or offset is @getLength()
      return null

    clone = @clone()
    clone.setString(@string.substr(offset))
    @setString(@string.substr(0, offset))
    clone

  mergeWithSpan: (span) ->
    false

  ###
  Section: Characters
  ###

  getOffset: ->
    @parent.getOffset(this) or 0

  getLength: ->
    @string.length

  getString: ->
    @string

  setString: (string='') ->
    delta = (string.length - @string.length)
    @string = string
    if delta
      each = @parent
      while each
        each.length += delta
        each = each.parent
    @

  deleteRange: (offset, length) ->
    newString = @string.slice(0, offset) + @string.slice(offset + length)
    @setString(newString)

  insertString: (offset, text) ->
    newString = @string.substr(0, offset) + text + @string.substr(offset)
    @setString(newString)

  appendString: (string) ->
    @insertString(@getLength(), string)

  ###
  Section: Spans
  ###

  getSpanIndex: ->
    @parent.getSpanIndex(this)

  getSpanCount: ->
    1

  ###
  Section: Debug
  ###

  toString: (extra) ->
    if extra
      "(#{@string}/#{extra})"
    else
      "(#{@string})"

module.exports = Span