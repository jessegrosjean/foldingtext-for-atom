{replace} = require './helpers'
Range = require './range'

class Line

  @parent: null
  @text: null

  constructor: (@text) ->

  getRow: ->
    @parent?.getRow(this) or 0

  getCharacterOffset: ->
    @parent?.getCharacterOffset(this) or 0

  getLineCount: ->
    1

  getText: ->
    @text

  getCharacterCount: ->
    @text.length + 1 # \n

  substr: (index) ->
    @text.substr(index)

  append: (content) ->
    end = @getCharacterCount()
    @setTextInRange(content, end, end)

  setTextInRange: (text, start, end) ->
    oldCount = @text.length
    @text = replace(@text, start, end, text)
    newCount = @text.length
    if delta = (newCount - oldCount)
      each = @parent
      while each
        each.characterCount += delta
        each = each.parent

module.exports = Line