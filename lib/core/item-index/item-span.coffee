LineSpan = require '../line-index/line-span'

class ItemSpan extends LineSpan

  constructor: (@item) ->
    super(@item.bodyText)

  clone: ->
    new @constructor(@item.cloneItem())

  split: (location) ->
    if location is 0 or location is @getLength()
      return null

    clone = @clone()
    clone.setString(@string.substr(location))
    @setString(@string.substr(0, location))
    clone

    debugger
    super(location)

  ###
  Section: Characters
  ###

  setString: (string='') ->
    super(string)

  deleteRange: (location, length) ->
    super(location, length)

  insertString: (location, text) ->
    super(location, text)

  ###
  Section: Debug
  ###

  toString: (extra) ->
    super(@item.id)

module.exports = ItemSpan