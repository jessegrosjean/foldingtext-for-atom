# Based off CodeMirror.js
class Line

  constructor: (@data, @characterCount) ->
    @parent = null

  getCharacterCount: ->
    @characterCount + 1 # \n

  setCharacterCount: (characterCount) ->
    delta = characterCount - @characterCount
    @characterCount = characterCount
    each = @parent
    while each
      each.characterCount += delta
      each = each.parent

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
      line = @lines[i]
      line.parent = null
      @characterCount -= line.characterCount
    @lines.splice(start, deleteCount)

  insertLines: (index, lines) ->
    for each in lines
      each.parent = this
      @characterCount += each.getCharacterCount()
    @lines = @lines.slice(0, index).concat(lines).concat(@lines.slice(index))

  iterateLines: (start, count, operation) ->
    for i in [start...start + count]
      if operation(@lines[i])
        return true

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
        if child.iterateLines(start, used, operation)
          return true
        if count -= used is 0
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

class LineManager extends BranchChunk

  constructor: ->
    super([new LeafChunk([])])

  insertLines: (location, lines) ->
    end = location
    if location < 0 or end > @lineCount
      throw new Error("Invalide line range: #{location}-#{end}");
    super(location, lines)

  removeLines: (location, count) ->
    end = location + count
    if location < 0 or end > @lineCount
      throw new Error("Invalide line range: #{location}-#{end}");
    super(location, count)

  iterateLines: (location, count, operation) ->
    end = location + count
    if location < 0 or end > @lineCount
      throw new Error("Invalide line range: #{location}-#{end}");
    super(location, count, operation)

  getLine: (lineNumber) ->
    if lineNumber < 0 or lineNumber >= @lineCount
      throw new Error("Invalide line number: #{lineNumber}");

    current = this
    while current
      if current.children
        for child in current.children
          childLineCount = child.getLineCount()
          if lineNumber > childLineCount
            lineNumber -= childLineCount
          else
            current = child
            break
      else
        return current.lines[lineNumber]

  getLineNumber: (line) ->
    unless line.parent
      return undefined

    current = line.parent
    lineNumber = current.lines.indexOf(line)
    chunk = current
    while chunk = chunk.parent
      for each in chunk.children
        if each is current
          break
        lineNumber += each.getLineCount()
      current = chunk
    return lineNumber

  getLineCount: ->
    super()

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

LineManager.Line = Line

module.exports = LineManager