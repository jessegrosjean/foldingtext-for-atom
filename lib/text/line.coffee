class Line

  @parent: null
  @marks: null
  @text: null

  @data: null
  @characterCount: null

  constructor: (@data, @characterCount) ->

  getLineCount: ->
    1

  getCharacterCount: ->
    @characterCount + 1 # \n

  setCharacterCount: (characterCount) ->
    delta = characterCount - @characterCount
    @characterCount = characterCount
    each = @parent
    while each
      each.characterCount += delta
      each = each.parent

  addMark: (mark) ->
    @marks ?= []
    @marks.push(mark)

  removeMark: (mark) ->
    @marks.splice(@marks.indexOf(mark), 1)

  replaceTextInRange: (insert, start, end) ->

module.exports = Line