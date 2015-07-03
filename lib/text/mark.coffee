class Mark

  parent: null
  range: null
  properties: null

  constructor: (@parent, @range, @properties) ->
    @parent.marks ?= []
    @parent.marks.push(this)

  destroy: ->
    marks = @parent.marks
    marks.splice(marks.indexOf(this), 1)

  getRange: ->
    @parent._getMarksRange(this)

module.exports = Mark