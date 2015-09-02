SpanIndex = require '../span-index'
Run = require './run'

class RunIndex extends SpanIndex

  getRunCount: ->
    @spanCount

  getRun: (index) ->
    @getSpan(index)

  getRunIndex: (child) ->
    @getSpanIndex(child)

  getRunIndexOffset: (offset, index=0) ->
    runIndexOffset = @getSpanAtOffset(offset, index)
    runIndexOffset.run = runIndexOffset.span
    runIndexOffset

  getRuns: (start, count) ->
    @getSpans(start, count)

  iterateRuns: (start, count, operation) ->
    @iterateSpans(start, count, operation)

  insertRuns: (start, lines) ->
    @insertSpans(start, lines)

  removeRuns: (start, deleteCount) ->
    @removeSpans(start, deleteCount)

  sliceRunsToRange: (offset, length) ->
    @sliceSpansToRange(offset, length)

  createRun: (text) ->
    @createSpan(text)

  createSpan: (text) ->
    new Run(text)

  ###
  Reading attributes
  ###

  getAttributesAtOffset: (offset, effectiveRange, longestEffectiveRange) ->
    start = @getRunIndexOffset(offset)
    result = start.run.attributes

    if effectiveRange
      effectiveRange.offset = start.startOffset
      effectiveRange.length = start.run.getLength()

    if longestEffectiveRange
      @_longestEffectiveRange start.index, start.run, longestEffectiveRange, (run) ->
        _.isEqual(run.attributes, result)

    result

  getAttributeAtOffset: (attribute, offset, effectiveRange, longestEffectiveRange) ->
    start = @getRunIndexOffset(offset)
    result = start.run.attributes[attribute]

    if effectiveRange
      effectiveRange.offset = start.startOffset
      effectiveRange.length = start.run.getLength()

    if longestEffectiveRange
      @_longestEffectiveRange start.index, start.run, longestEffectiveRange, (run) ->
        run.attributes[attribute] is result

    result

  _longestEffectiveRange: (runIndex, attributeRun, range, shouldExtendRunToInclude) ->
    nextIndex = runIndex - 1
    currentRun = attributeRun

    # scan backwards
    while nextIndex >= 0
      nextRun = @getRun(nextIndex)
      if shouldExtendRunToInclude(nextRun)
        currentRun = nextRun
        nextIndex--
      else
        break

    range.offset = currentRun.getOffset()
    nextIndex = runIndex + 1
    currentRun = attributeRun

    # scan forwards
    while nextIndex < @getRunCount()
      nextRun = @getRun(nextIndex)
      if shouldExtendRunToInclude(nextRun)
        currentRun = nextRun
        nextIndex++
      else
        break

    range.length = (currentRun.getOffset() + currentRun.getLength()) - range.offset
    range

  ###
  Changing attributes
  ###

  sliceAndIterateRunsByOffset: (offset, length, operation) ->
    slice = @sliceRunsToRange(offset, length)
    @iterateSpans(slice.index, slice.count, operation)

  setAttributesInRange: (attributes, offset, length) ->
    @sliceAndIterateRunsByOffset offset, length, (run) ->
      run.setAttributes(attributes)

  addAttributeInRange: (attribute, value, offset, length) ->
    @sliceAndIterateRunsByOffset offset, length, (run) ->
      run.addAttribute(attribute, value)

  addAttributesInRange: (attributes, offset, length) ->
    @sliceAndIterateRunsByOffset offset, length, (run) ->
      run.addAttributes(attributes)

  removeAttributeInRange: (attribute, offset, length) ->
    @sliceAndIterateRunsByOffset offset, length, (run) ->
      run.removeAttribute(attribute)

  ###
  Changing characters and attributes
  ###

  insertRunIndex: (runIndex, offset) ->

module.exports = RunIndex