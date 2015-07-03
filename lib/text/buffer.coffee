BufferBranch = require './buffer-branch'
BufferLeaf = require './buffer-leaf'
{newlineRegex} = require './helpers'
Range = require './range'
Point = require './point'
Line = require './line'

class Buffer extends BufferBranch

  constructor: ->
    super([new BufferLeaf([])])

  ###
  Section: Text
  ###

  getText: ->
    if @cachedText
      @cachedText
    else
      textLines = []
      @iterateLines 0, @getLineCount(), (line) ->
        textLines.push(line.getText())
      @cachedText = textLines.join('\n')
      @cachedText

  getTextInRange: (range) ->
    range = @clipRange(Range.fromObject(range))
    startRow = range.start.row
    endRow = range.end.row

    if startRow is endRow
      @getLine(startRow).getText()[range.start.column...range.end.column]
    else
      text = ''
      lines = []
      row = startRow
      @iterateLines startRow, (endRow - startRow) + 1, (line) ->
        lineText = line.getText()
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
      startLine.setTextInRange(newLines.shift(), startColumn, endColumn)
    else
      # 1. Save end suffix
      endSuffix = endLine.substr(endColumn)

      # 2. Replace in first line
      startLine.setTextInRange(newLines.shift(), startColumn, startLine.getText().length)

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
        lastLine = insertLines?[insertLines.length - 1] ? startLine
        lastLine.append(endSuffix)

    @cachedText = null

    newRange

  ###
  Section: Lines
  ###

  getLine: (row) ->
    if row < 0 or row >= @lineCount
      throw new Error("Invalide line number: #{row}");
    super(row)

  getLineRowColumn: (characterOffset) ->
    if characterOffset < 0 or characterOffset > @getCharacterCount()
      throw new Error("Invalide character offset: #{characterOffset}");
    super(characterOffset)

  iterateLines: (row, count, operation) ->
    end = row + count
    if row < 0 or end > @lineCount
      throw new Error("Invalide line range: #{row}-#{end}");
    super(row, count, operation)

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

  ###
  Section: Range Details
  ###

  getRange: ->
    new Range(@getFirstPosition(), @getEndPosition())

  getLineCount: ->
    super()

  getLastRow: ->
    @getLineCount() - 1

  getFirstPosition: ->
    new Point(0, 0)

  getEndPosition: ->
    lastRow = @getLastRow()
    new Point(lastRow, @getLine(lastRow).getText().length)

  getCharacterCount: ->
    if @getLineCount() > 0
      # Internally each line +1's its character count to account for the \n.
      # But the last line doesn't actually have a \n so account for that by -1
      super() - 1
    else
      super()

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
      column = Math.min(Math.max(column, 0), @getLine(row).getText().length)
      if column is position.column
        position
      else
        new Point(row, column)

  ###
  Section: Text Line Overrides
  ###

  createLineFromText: (text) ->
    new Line(text)

module.exports = Buffer