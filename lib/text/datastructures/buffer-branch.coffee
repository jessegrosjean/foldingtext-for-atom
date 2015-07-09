BufferLeaf = require './buffer-leaf'
Range = require '../range'

class BufferBranch

  constructor: (@children) ->
    @parent = null
    lineCount = 0
    characterCount = 0
    for each in @children
      each.parent = this
      lineCount += each.getLineCount()
      characterCount += each.getCharacterCount()
    @lineCount = lineCount
    @characterCount = characterCount

  ###
  Section: Lines
  ###

  getLineCount: ->
    @lineCount

  getCharacterCount: ->
    @characterCount

  getLine: (row) ->
    for each in @children
      childLineCount = each.getLineCount()
      if row > childLineCount
        row -= childLineCount
      else
        return each.getLine(row)

  getRow: (child) ->
    row = @parent?.getRow(this) or 0
    if child
      for each in @children
        if each is child
          break
        row += each.getLineCount()
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
      if characterOffset > childCharacterCount
        characterOffset -= childCharacterCount
        row += each.getLineCount()
      else
        return each.getLineRowColumn(characterOffset, row)

  iterateLines: (start, count, operation) ->
    for child in @children
      childLineCount = child.getLineCount()
      if start < childLineCount
        used = Math.min(count, childLineCount - start)
        child.iterateLines(start, used, operation)
        if (count -= used) is 0
          break
        start = 0
      else
        start -= childLineCount

  insertLines: (start, lines) ->
    @lineCount += lines.length

    for each in lines
      @characterCount += each.getCharacterCount()

    for child, i in @children
      childLineCount = child.getLineCount()
      if start <= childLineCount
        child.insertLines(start, lines)
        if child instanceof BufferLeaf and child.children.length > 50
          while child.children.length > 50
            spilled = child.children.splice(child.children.length - 25, 25)
            newleaf = new BufferLeaf(spilled)
            child.characterCount -= newleaf.characterCount
            @children.splice(i + 1, 0, newleaf)
            newleaf.parent = this
          @maybeSpill()
        break
      start -= childLineCount

  removeLines: (start, deleteCount) ->
    @lineCount -= deleteCount
    i = 0
    while child = @children[i]
      childLineCount = child.getLineCount()
      if start < childLineCount
        childDeleteCount = Math.min(deleteCount, childLineCount - start)
        childOldCharactersCount = child.getCharacterCount()
        child.removeLines(start, childDeleteCount)
        @characterCount -= (childOldCharactersCount - child.getCharacterCount())
        if childLineCount is childDeleteCount
          @children.splice(i--, 1)
          child.parent = null
        if (deleteCount -= childDeleteCount) is 0
          break
        start = 0
      else
        start -= childLineCount
      i++
    @maybeCollapse(deleteCount)

  ###
  Section: Tree Balance
  ###

  maybeSpill: ->
    if @children.length <= 10
      return

    current = this
    while current.children.length > 10
      spilled = current.children.splice(current.children.length - 5, 5)
      sibling = new BufferBranch(spilled)
      if current.parent
        current.lineCount -= sibling.lineCount
        current.characterCount -= sibling.characterCount
        index = current.parent.children.indexOf(current)
        current.parent.children.splice(index + 1, 0, sibling)
      else
        copy = new BufferBranch(current.children)
        copy.parent = current
        current.children = [copy, sibling]
        current = copy
      sibling.parent = current.parent
    current.parent.maybeSpill()

  maybeCollapse: (deleteCount) ->
    if (@lineCount - deleteCount) > 25
      return

    if @children.length > 1 or not (@children[0] instanceof BufferLeaf)
      lines = []
      @collapse(lines)
      @children = [new BufferLeaf(lines)]
      @children[0].parent = this

  collapse: (lines) ->
    for each in @children
      each.collapse(lines)

module.exports = BufferBranch