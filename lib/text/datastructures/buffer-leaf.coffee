Range = require '../range'

class BufferLeaf

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

  getRow: (child) ->
    row = @parent?.getRow(this) or 0
    if child
      row += @children.indexOf(child)
    row

  getCharacterOffset: (child) ->
    characterOffset = @parent?.getCharacterOffset(this) or 0
    if child
      for each in @children
        if each is child
          break
        characterOffset += each.getCharacterCount()
    characterOffset

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

  removeLines: (start, deleteCount) ->
    end = start + deleteCount
    for i in [start...end]
      each = @children[i]
      each.parent = null
      @characterCount -= each.getCharacterCount()
    @children.splice(start, deleteCount)

  ###
  Section: Util
  ###

  collapse: (lines) ->
    @children.push.apply(lines, @children)

module.exports = BufferLeaf