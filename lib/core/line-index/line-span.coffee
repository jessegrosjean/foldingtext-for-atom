Span = require '../span-index/span'
assert = require 'assert'

class LineSpan extends Span

  
  constructor: (text) ->
    super(text)

  setString: (string='') ->
    i = string.indexOf('\n')
    assert(i is -1 or i is string.length - 1)
    super(string)

  deleteRange: (location, length) ->
    super(location, length)

  insertString: (location, text) ->
    super(location, text)

module.exports = LineSpan