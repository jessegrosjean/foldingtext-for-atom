Span = require '../span-buffer/span'
assert = require 'assert'

class LineSpan extends Span

  constructor: (text) ->
    super(text)

  getLineContent: ->
    @string

  getLineContentSuffix: (location) ->
    @getLineContent().substr(location)

  getLength: ->
    length = @string.length
    if @isLast
      length
    else
      length + 1

  getString: ->
    if @isLast
      @string
    else
      @string + '\n'

  setString: (string='') ->
    assert(string.indexOf('\n') is -1)
    super(string)

  setIsLast: (isLast) ->
    if @isLast isnt isLast
      delta = if isLast then -1 else 1
      each = @indexParent
      while each
        each.length += delta
        each = each.indexParent
      @isLast = isLast

  deleteRange: (location, length) ->
    super(location, length)

  insertString: (location, text) ->
    super(location, text)

module.exports = LineSpan