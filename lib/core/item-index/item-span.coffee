LineSpan = require '../line-index/line-span'

class ItemSpan extends LineSpan

  constructor: (@item) ->
    super(@item.bodyText)

  clone: ->
    new @constructor(@item.cloneItem(false))

  ###
  Section: Characters
  ###

  setString: (string='') ->
    super(string)

    content = @getLineContent()
    if root = @getRoot()
      unless root.isUpdatingIndex
        root.isUpdatingItems++
        @item.bodyText = content
        root.isUpdatingItems--
    else
      @item.bodyText = content

  deleteRange: (location, length) ->
    super(location, length)

    #if location + length > @item.bodyText.length
    #  length--

    #if root = @getRoot()
    #  unless root.isUpdatingIndex
    #    root.isUpdatingItems++
    #    @item.replaceBodyTextInRange('', location, length)
    #    root.isUpdatingItems--
    #else
    #  @item.replaceBodyTextInRange('', location, length)

  insertString: (location, text) ->
    super(location, text)

    #if location is @getLength() - 1 and text[text.length - 1] is '\n'
    #  text = text.substr(0, -1)

    #if root = @getRoot()
    #  unless root.isUpdatingIndex
    #    root.isUpdatingItems++
    #    @item.replaceBodyTextInRange(text, location, 0)
    #    root.isUpdatingItems--
    #else
    #  @item.replaceBodyTextInRange(text, location, 0)

  ###
  Section: Debug
  ###

  toString: ->
    super(@item.id)

module.exports = ItemSpan