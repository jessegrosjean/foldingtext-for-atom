Range = require './range'
Mark = require './mark'

class Line

  @parent: null
  @marks: null
  @text: null

  @data: null
  @characterCount: null

  constructor: (@data, @characterCount) ->

  getRow: ->
    @parent?.getRow(this) or 0

  getCharacterOffset: ->
    @parent?.getCharacterOffset(this) or 0

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

  ###
  Section: Marks
  ###

  markRange: (start, end, properties) ->
    new Mark(this, [start, end], properties)

  _getMarksRange: (mark) ->
    row = @getRow()
    new Range([row, mark.range[0]], [row, mark.range[1]])

  iterateBuffer: (context, operation) ->

    markSet = {}
    column = 0

    for each in @points
      if each.column isnt column
        emit(column, each.column, markSet)
        column = each.column

      if each.isStart
        markSet.add(each)
      else if each.isEnd
        markSet.remove(each)



    for each in @markPoints
      if each.column > emittedToColumn
        emit(column, each.column, markSet)
        column = each.column

      if each.isStart
        markSet.add(each.mark)
      else if each.isEnd
        if each.mark.isCollapsed()
          emit(column, each.column, markSet)
        markSet.remove(each.mark)


    if emmitedToColumn < @text.length
      emit()

    column = 0

    stack = []
    for each in @marks
      if column < each.start
        emit(column, each.start, stack)
        column = each.start


      if lastMark.start is each.start
        stack.push each
      else



    marksStack = []

    if @marks
      for each in @marks
        context.pushMark(each)
        context.emitToMark()

        marksStack.push(each)

        if emitStart < each.start

          operation(@text.substr(emitStart, each.start))
          emitStart = each.start
        each.start

    if emitIndex < @text.length
      emit(@text.substr(emitIndex, @text.length - emitIndex), marksStack)

  ###
  Section: Text
  ###

  replaceRangeText: (start, end, text) ->

module.exports = Line