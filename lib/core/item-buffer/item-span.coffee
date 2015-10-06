AttributedString = require '../attributed-string'
LineSpan = require '../line-buffer/line-span'

class ItemSpan extends LineSpan

  constructor: (@item) ->
    super(@item.bodyString)
    @bodyAttributedString = @item.bodyAttributedString.clone()

  clone: ->
    new @constructor(@item.cloneItem(false))

  ###
  Section: Characters
  ###

  getLineContentSuffix: (location) ->
    @bodyAttributedString.subattributedString(location, -1)

  replaceRange: (location, length, text) ->
    if text instanceof AttributedString
      string = text.string
    else
      string = text

    super(location, length, string)

    @bodyAttributedString.replaceRange(location, length, text)

    if root = @getRoot()
      unless root.isUpdatingIndex
        root.isUpdatingItems++
        @item.replaceBodyRange(location, length, text)
        root.isUpdatingItems--
    else
      @item.replaceBodyRange(location, length, text)

  ###
  Section: Debug
  ###

  toString: ->
    super(@item.id)

module.exports = ItemSpan