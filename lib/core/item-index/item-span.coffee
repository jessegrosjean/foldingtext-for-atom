LineSpan = require '../line-index/line-span'

class ItemSpan extends LineSpan

  constructor: (@item) ->
    super(@item.bodyText)

  clone: ->
    new @constructor(@item.cloneItem(false))

  ###
  Section: Characters
  ###

  replaceRange: (location, length, string) ->
    super(location, length, string)

    if root = @getRoot()
      unless root.isUpdatingIndex
        root.isUpdatingItems++
        @item.replaceBodyTextInRange(string, location, length)
        root.isUpdatingItems--
    else
      @item.replaceBodyTextInRange(string, location, length)

  ###
  Section: Debug
  ###

  toString: ->
    super(@item.id)

module.exports = ItemSpan