BufferBranch = require './b-tree/buffer-branch'
BufferLeaf = require './b-tree/buffer-leaf'
{newlineRegex} = require './helpers'
{Emitter} = require 'atom'
Range = require './range'
Point = require './point'
Line = require './line'

class Buffer extends BufferBranch

  constructor: ->
    super([new BufferLeaf([])])
    @changing = 0
    @emitter = new Emitter()

  destroy: ->
    unless @destroyed
      @destroyed = true
      @emitter.emit 'did-destroy'

  ###
  Section: Events
  ###

  onDidBeginChanges: (callback) ->
    @emitter.on 'did-begin-changes', callback

  onWillChange: (callback) ->
    @emitter.on 'will-change', callback

  onDidChange: (callback) ->
    @emitter.on 'did-change', callback

  onDidEndChanges: (callback) ->
    @emitter.on 'did-end-changes', callback

  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

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
    if @getLineCount() is 0
      @insertLines(0, [@createLineFromText('')])

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
    startOffset = startLine.getCharacterOffset()

    unless @changing
      changeEvent =
        oldRange: oldRange.copy()
        oldCharacterRange: @getCharacterRangeFromRange(oldRange)
        oldText: @getTextInRange(oldRange)
        newRange: newRange.copy()
        newCharacterRange: start: startOffset, end: startOffset + newText.length
        newText: newText
      @emitter.emit 'will-change', changeEvent

    @changing++

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
      if endSuffix.length
        lastLine = insertLines?[insertLines.length - 1] ? startLine
        lastLine.append(endSuffix)

    @cachedText = null

    @changing--

    unless @changing
      @emitter.emit 'did-change', changeEvent

    newRange

  ###
  Section: Lines
  ###

  getLine: (row) ->
    if row < 0 or row >= @lineCount
      return undefined
    super(row)

  getLineRowColumn: (characterOffset) ->
    if characterOffset < 0 or characterOffset > @getCharacterCount()
      return undefined
    super(characterOffset)

  getLinesInRange: (range) ->
    range = @clipRange(Range.fromObject(range))
    startRow = range.start.row
    endRow = range.end.row

    lines = []
    @iterateLines startRow, (endRow - startRow) + 1, (line) ->
      lines.push line
    lines

  iterateLines: (row, count, operation) ->
    end = row + count
    if row < 0 or end > @lineCount
      throw new Error("Invalide line range: #{row}-#{end}");
    super(row, count, operation)

  insertLines: (row, lines) ->
    return unless lines.length

    end = row
    if row < 0 or end > @lineCount
      throw new Error("Invalide line range: #{row}-#{end}");

    unless @changing
      newText = (each.getText() for each in lines).join('\n')
      oldRange = new Range([row, 0], [row, 0])
      startOffset
      newRange

      if row is @lineCount
        if row is 0
          lastLineIndex = row + lines.length - 1
          lastLine = lines[lastLineIndex]
          newRange = new Range([row, 0], [lastLineIndex, lastLine.getCharacterCount() - 1])
          startOffset = 0
        else
          newRange = new Range([row, 0], [row + lines.length, 0])
          newText = '\n' + newText
          prevLine = @getLine(row - 1)
          prevLineLength = prevLine.getCharacterCount()
          startOffset = prevLine.getCharacterOffset() + prevLineLength - 1
          oldRange = new Range([row - 1, prevLineLength - 1], [row - 1, prevLineLength - 1])
      else
        newText += '\n'
        newRange = new Range([row, 0], [row + lines.length, 0])
        startOffset = @getCharacterOffsetFromPoint(newRange.start)

      newCharacterRange =
        start: startOffset
        end: startOffset + newText.length

      changeEvent =
        oldRange: oldRange
        oldCharacterRange: @getCharacterRangeFromRange(oldRange)
        oldText: ''
        newRange: newRange
        newCharacterRange: newCharacterRange
        newText: newText
      @emitter.emit 'will-change', changeEvent

    @changing++
    super(row, lines)
    @cachedText = null
    @changing--

    unless @changing
      @emitter.emit 'did-change', changeEvent

  removeLines: (row, count) ->
    return unless count

    end = row + count
    if row < 0 or end > @lineCount
      throw new Error("Invalide line range: #{row}-#{end}");

    unless @changing
      oldRange = new Range([row, 0], [end, 0])
      newRange = new Range([row, 0], [row, 0])

      if end is @lineCount
        oldRange.end.row = end - 1
        oldRange.end.column = this.getLine(end - 1).getCharacterCount() - 1

      changeEvent =
        oldRange: oldRange
        oldCharacterRange: @getCharacterRangeFromRange(oldRange)
        oldText: @getTextInRange(oldRange)
        newRange: newRange
        newCharacterRange: @getCharacterRangeFromRange(newRange)
        newText: ''
      @emitter.emit 'will-change', changeEvent

    @changing++
    super(row, count)
    @cachedText = null
    @changing--

    unless @changing
      @emitter.emit 'did-change', changeEvent

  ###
  Section: Range Details
  ###

  getRange: ->
    new Range(@getFirstPosition(), @getEndPosition())

  getCharacterRangeFromRange: (range) ->
    start = @getCharacterOffsetFromPoint(range.start)
    if range.isSingleLine()
      end = start + (range.end.column - range.start.column)
    else
      end = @getCharacterOffsetFromPoint(range.end)
    start: start, end: end

  getRangeFromCharacterRange: (startOffset, endOffset) ->
    if endOffset is 0
      return new Range()
    start = @getLineRowColumn(startOffset)
    if startOffset is endOffset
      end = start
    else
      end = @getLineRowColumn(endOffset)
    new Range([start.row, start.column], [end.row, end.column])

  getLineCount: ->
    super()

  getLastRow: ->
    @getLineCount() - 1

  getFirstPosition: ->
    new Point(0, 0)

  getEndPosition: ->
    lastRow = @getLastRow()
    if lastRow is -1
      @getFirstPosition()
    else
      new Point(lastRow, @getLine(lastRow).getText().length)

  getCharacterOffsetFromPoint: (point) ->
    if point.isZero()
      0
    else
      @getLine(point.row).getCharacterOffset() + point.column

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