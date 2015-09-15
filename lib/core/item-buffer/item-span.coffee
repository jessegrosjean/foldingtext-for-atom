LineSpan = require '../line-buffer/line-span'

class ItemSpan extends LineSpan

  constructor: (@item) ->
    super(@item.bodyString)

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
        @item.replaceBodyRange(location, length, string)
        root.isUpdatingItems--
    else
      @item.replaceBodyRange(location, length, string)

  ###
  Section: Debug
  ###

  toString: ->
    super(@item.id)

module.exports = ItemSpan