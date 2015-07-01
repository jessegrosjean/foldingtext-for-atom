{replace, newlineRegex} = require './helpers'
Range = require './range'
Point = require './point'
Line = require './line'

# Based off CodeMirror.js
class LeafChunk

  constructor: (@lines) ->
    @parent = null
    characterCount = 0
    for each in @lines
      each.parent = this
      characterCount += each.getCharacterCount()
    @characterCount = characterCount

  removeLines: (start, deleteCount) ->
    for i in [start...start + deleteCount]
      each = @lines[i]
      each.parent = null
      @characterCount -= each.getCharacterCount()
    @lines.splice(start, deleteCount)

  insertLines: (index, lines) ->
    for each in lines
      each.parent = this
      @characterCount += each.getCharacterCount()
    @lines = @lines.slice(0, index).concat(lines).concat(@lines.slice(index))

  iterateLines: (start, count, operation) ->
    for i in [start...start + count]
      operation(@lines[i])

  collapse: (lines) ->
    @lines.push.apply(lines, @lines)

  getLineCount: ->
    @lines.length

  getCharacterCount: ->
    @characterCount

class BranchChunk

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

  removeLines: (start, deleteCount) ->
    @lineCount -= deleteCount

    for child, i in @children
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

    if @lineCount - deleteCount < 25 and
       (@children.length > 1 or not (@children[0] instanceof LeafChunk))

      lines = []
      @collapse(lines)
      @children = [new LeafChunk(lines)]
      @children[0].parent = this

  insertLines: (start, lines) ->
    @lineCount += lines.length

    for each in lines
      @characterCount += each.getCharacterCount()

    for child, i in @children
      childLineCount = child.getLineCount()
      if start <= childLineCount
        child.insertLines(start, lines)
        if child.lines?.length > 50
          while child.lines.length > 50
            spilled = child.lines.splice(child.lines.length - 25, 25)
            newleaf = new LeafChunk(spilled)
            child.characterCount -= newleaf.characterCount
            @children.splice(i + 1, 0, newleaf)
            newleaf.parent = this
          @maybeSpill()
        break
      start -= childLineCount

  maybeSpill: ->
    if @children.length <= 10
      return
    current = this
    while current.children.length > 10
      spilled = current.children.splice(current.children.length - 5, 5)
      sibling = new BranchChunk(spilled)
      unless current.parent
        copy = new BranchChunk(current.children)
        copy.parent = current
        current.children = [copy, sibling]
        current = copy
      else
        current.lineCount -= sibling.lineCount
        current.characterCount -= sibling.characterCount
        index = current.parent.children.indexOf(current)
        current.parent.children.splice(index + 1, 0, sibling)
      sibling.parent = current.parent
    current.parent.maybeSpill()

  iterateLines: (start, count, operation) ->
    for child in @children
      childLineCount = child.getLineCount()
      if (start < childLineCount)
        used = Math.min(count, childLineCount - start)
        child.iterateLines(start, used, operation)
        if (count -= used) is 0
          break
        start = 0
      else
        start -= childLineCount

  collapse: (lines) ->
    for each in @children
      each.collapse(lines)

  getLineCount: ->
    @lineCount

  getCharacterCount: ->
    @characterCount

class TextBuffer extends BranchChunk

  constructor: ->
    super([new LeafChunk([])])

  ###
  Section: Lines
  ###

  insertLines: (row, lines) ->
    end = row
    if row < 0 or end > @lineCount
      throw new Error("Invalide line range: #{row}-#{end}");
    super(row, lines)
    @cachedText = null

  removeLines: (row, count) ->
    end = row + count
    if row < 0 or end > @lineCount
      throw new Error("Invalide line range: #{row}-#{end}");
    super(row, count)
    @cachedText = null

  iterateLines: (row, count, operation) ->
    end = row + count
    if row < 0 or end > @lineCount
      throw new Error("Invalide line range: #{row}-#{end}");
    super(row, count, operation)

  getLine: (row) ->
    if row < 0 or row >= @lineCount
      throw new Error("Invalide line number: #{row}");

    current = this
    while current
      if current.children
        for child in current.children
          childLineCount = child.getLineCount()
          if row > childLineCount
            row -= childLineCount
          else
            current = child
            break
      else
        return current.lines[row]

  getRow: (line) ->
    unless line.parent
      return undefined

    current = line.parent
    row = current.lines.indexOf(line)
    chunk = current
    while chunk = chunk.parent
      for each in chunk.children
        if each is current
          break
        row += each.getLineCount()
      current = chunk
    return row

  getLineCount: ->
    super()

  ###
  Section: Text
  ###

  getText: ->
    if @cachedText
      @cachedText
    else
      textLines = []
      @iterateLines 0, @getLineCount(), (line) =>
        textLines.push(@getLineText(line))
      @cachedText = textLines.join('\n')
      @cachedText

  getTextInRange: (range) ->
    range = @clipRange(Range.fromObject(range))
    startRow = range.start.row
    endRow = range.end.row

    if startRow is endRow
      @getLineText(@getLine(startRow))[range.start.column...range.end.column]
    else
      text = ''
      lines = []
      row = startRow
      @iterateLines startRow, (endRow - startRow) + 1, (line) =>
        lineText = @getLineText(line)
        if row is startRow
          lines.push lineText[range.start.column...]
        else if row is endRow
          lines.push lineText[0...range.end.column]
        else
          lines.push lineText
        row++
      lines.join('\n')

  setTextInRange: (newText, range) ->
    oldRange = @clipRange(range)
    newRange = Range.fromText(oldRange.start, newText)
    startRow = oldRange.start.row
    startColumn = oldRange.start.column
    endRow = oldRange.end.row
    endColumn = oldRange.end.column
    newLines = newText.split(newlineRegex)
    effectsSingleLine = startRow is endRow
    startLine = @getLine(startRow)
    endLine = @getLine(endRow)

    if newLines.length is 1 and effectsSingleLine
      @replaceLineTextInRange(startLine, startColumn, endColumn - startColumn, newLines.shift())
    else
      # 1. Save end suffix
      endSuffix = @getLineText(endLine).substr(endColumn)

      # 2. Replace in first line
      @replaceLineTextInRange(startLine, startColumn, @getLineText(startLine).length - startColumn, newLines.shift())

      # 3. Remove all trialing effected lines
      removeLineCount = endRow - startRow
      if removeLineCount > 0
        @removeLines(startRow + 1, removeLineCount)

      # 4. Insert new lines
      if newLines.length > 0
        insertLines = []
        for each in newLines
          insertLines.push @createLineFromText(each)
        @insertLines(startRow + 1, insertLines)

      # 5. Append end suffix to last inserted line
      if endSuffix
        lastLine = if insertLines then insertLines[insertLines.length - 1] else startLine
        @replaceLineTextInRange(lastLine, @getLineText(lastLine).length, 0, endSuffix)

    @cachedText = null

    newRange

  ###
  Section: Text Line Overrides
  ###

  getLineText: (line) ->
    line.data

  replaceLineTextInRange: (line, start, length, text) ->
    line.data = replace(line.data, start, start + length, text)
    line.setCharacterCount(line.data.length)

  createLineFromText: (text) ->
    new Line(text, text.length)

  ###
  Section: Characters
  ###

  getLineCharacterOffset: (characterOffset) ->
    if characterOffset < 0 or characterOffset > @getCharacterCount()
      throw new Error("Invalide character offset: #{characterOffset}");

    current = this
    while current
      if current.children
        for child in current.children
          childCharacterCount = child.getCharacterCount()
          if characterOffset >= childCharacterCount
            characterOffset -= childCharacterCount
          else
            current = child
            break
      else
        for each in current.lines
          lineCharacterCount = each.getCharacterCount()
          if characterOffset >= lineCharacterCount
            characterOffset -= lineCharacterCount
          else
            return {} =
              line: each
              characterOffset: characterOffset

  getCharacterOffset: (line) ->
    unless line.parent
      return undefined

    leafChunk = line.parent
    characterOffset = 0
    for each in leafChunk.lines
      if each is line
        break
      characterOffset += each.getCharacterCount()

    chunk = leafChunk
    current = chunk
    while chunk = chunk.parent
      for each in chunk.children
        if each is current
          break
        characterOffset += each.getCharacterCount()
      current = chunk
    return characterOffset

  getCharacterCount: ->
    if lineCount = @getLineCount()
      # Internally each line +1's its character count to account for the \n.
      # But the last line doesn't actually have a \n so account for that by -1
      super() - 1
    else
      super()

  ###
  Section: Util
  ###

  getRange: ->
    new Range(@getFirstPosition(), @getEndPosition())

  getLastRow: ->
    @getLineCount() - 1

  getFirstPosition: ->
    new Point(0, 0)

  getEndPosition: ->
    lastRow = @getLastRow()
    new Point(lastRow, @getLineText(@getLine(lastRow)).length)

  clipRange: (range) ->
    range = Range.fromObject(range)
    start = @clipPosition(range.start)
    end = @clipPosition(range.end)
    if range.start.isEqual(start) and range.end.isEqual(end)
      range
    else
      new Range(start, end)

  clipPosition: (position) ->
    position = Point.fromObject(position)
    Point.assertValid(position)
    {row, column} = position
    if row < 0
      @getFirstPosition()
    else if row > @getLastRow()
      @getEndPosition()
    else
      column = Math.min(Math.max(column, 0), @getLineText(@getLine(row)).length)
      if column is position.column
        position
      else
        new Point(row, column)

module.exports = TextBuffer