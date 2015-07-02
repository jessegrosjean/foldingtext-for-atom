class LinesLeaf

  marks: null

  constructor: (@children) ->
    @parent = null
    characterCount = 0
    for each in @children
      each.parent = this
      characterCount += each.getCharacterCount()
    @characterCount = characterCount

  ###
  Section: Lines
  ###

  getLineCount: ->
    @children.length

  getCharacterCount: ->
    @characterCount

  getLine: (row) ->
    @children[row]

  getLineRowColumn: (characterOffset, row=0) ->
    for each in @children
      childCharacterCount = each.getCharacterCount()
      if characterOffset >= childCharacterCount
        characterOffset -= childCharacterCount
        row++
      else
        return {} =
          line: each
          row: row
          column: characterOffset

  iterateLines: (start, count, operation) ->
    for i in [start...start + count]
      operation(@children[i])

  insertLines: (index, lines) ->
    for each in lines
      each.parent = this
      @characterCount += each.getCharacterCount()
    @children = @children.slice(0, index).concat(lines).concat(@children.slice(index))

    if @marks
      for each in @marks
        each.insertedLines(index, index + lines.length)

  removeLines: (start, deleteCount) ->
    end = start + deleteCount
    for i in [start...end]
      each = @children[i]
      each.parent = null
      @characterCount -= each.getCharacterCount()
    @children.splice(start, deleteCount)

    if @marks
      for each in @marks
        each.deletedLines(start, end)

  ###
  Section: Marks
  ###

  markLines: (startLine, startColumn, endLine, endColumn, properties) ->
    if start is end
      line = @children[start]
      line.addMark(new Mark(line, 0, startColumn, 0, endColumn))
    else
      @marks ?= []
      @marks.push(new Mark(this, startLine, startColumn, endLine, endColumn, properties))

  iterateMarks: (startLine, startColumn, endLine, endColumn, operation) ->
    if start is end
      line.iterateMarks(0, startColumn, 0, endColumn, operation)
    else
      if @marks
        for each in @marks
          operation(each)

      for i in [startLine...endLine]
        if i is startLine
          @children[i].iterateMarks(0, startColumn, 0, null, operation)
        else if i is endLine
          @children[i].iterateMarks(0, null, 0, endColumn, operation)
        else
          @children[i].iterateMarks(0, null, 0, null, operation)

  ###
  Section: Tree Balance
  ###

  maybeSpill: ->
    while @children.length > 50
      spilled = @children.splice(@children.length - 25, 25)
      newleaf = new LinesLeaf(spilled)
      @characterCount -= newleaf.characterCount
      @parent.children.splice(i + 1, 0, newleaf)
      newleaf.parent = @parent

  collapse: (lines) ->
    @children.push.apply(lines, @children)

module.exports = LinesLeaf