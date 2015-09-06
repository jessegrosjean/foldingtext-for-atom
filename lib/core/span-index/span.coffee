_ = require 'underscore-plus'

class Span

  constructor: (@string='') ->
    @indexParent = null

  clone: ->
    new @constructor(@string)

  split: (location) ->
    if location is 0 or location is @getLength()
      return null

    clone = @clone()
    clone.deleteRange(0, location)
    @deleteRange(location, @getLength() - location)
    clone

  mergeWithSpan: (span) ->
    false

  ###
  Section: Characters
  ###

  getLocation: ->
    @indexParent.getLocation(this) or 0

  getLength: ->
    @string.length

  getString: ->
    @string

  setString: (string='') ->
    delta = (string.length - @string.length)
    @string = string
    if delta
      each = @indexParent
      while each
        each.length += delta
        each = each.indexParent
    @

  deleteRange: (location, length) ->
    newString = @string.slice(0, location) + @string.slice(location + length)
    @setString(newString)

  insertString: (location, text) ->
    newString = @string.substr(0, location) + text + @string.substr(location)
    @setString(newString)

  replaceRange: (location, length, string) ->
    @insertString(location, string)
    @deleteRange(location + string.length, length)

  appendString: (string) ->
    @insertString(@getLength(), string)

  ###
  Section: Spans
  ###

  getRoot: ->
    each = @indexParent
    while each
      if each.isRoot
        return each
      each = each.indexParent
    null

  getSpanIndex: ->
    @indexParent.getSpanIndex(this)

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