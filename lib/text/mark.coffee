class Mark

  parent: null
  startCharacter: null
  endCharacter: null
  properties: null

  constructor: (@parent, @startCharacter, @endCharacter, @properties) ->

  destroy: ->
    parent.removeMark(this)

  getRange: ->
    anchorRow = @buffer.getRow(@anchorLine)
    headRow = if @anchorLine is @headLine then anchorRow else @buffer.getRow(@headLine)
    new Range([anchorRow, @anchorColumn], [headRow, @headColumn])

module.exports = Mark