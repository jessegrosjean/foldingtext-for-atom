class Line

  constructor: (@data, @characterCount) ->
    @parent = null

  getCharacterCount: ->
    @characterCount + 1 # \n

  setCharacterCount: (characterCount) ->
    delta = characterCount - @characterCount
    @characterCount = characterCount
    each = @parent
    while each
      each.characterCount += delta
      each = each.parent

module.exports = Line