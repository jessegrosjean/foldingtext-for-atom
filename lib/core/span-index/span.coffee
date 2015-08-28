_ = require 'underscore-plus'

class Span

  @parent: null
  @length: 0

  constructor: (textLength) ->
    if _.isString textLength
      @length = textLength.length
    else
      @length = textLength

  clone: ->
    clone = new @constructor()
    clone.setLength(@length)
    clone

  split: (offset) ->
    if offset is 0 or offset is @length
      return null

    clone = @clone()
    clone.setLength(@length - offset)
    @setLength(offset)
    clone

  ###
  Section: Characters
  ###

  getOffset: ->
    @parent.getOffset(this) or 0

  getLength: ->
    @length

  setLength: (length) ->
    if delta = (length - @length)
      each = @parent
      while each
        each.length += delta
        each = each.parent
    @length = length

  deleteRange: (offset, length) ->
    @setLength(@getLength() - length)

  insertText: (offset, text) ->
    @setLength(@getLength() + text.length)

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

  toString: ->
    offset = @getOffset()
    length = @getLength()
    if length <= 1
      "#{offset}"
    else
      "#{offset}-#{offset + @getLength() - 1}"

module.exports = Span