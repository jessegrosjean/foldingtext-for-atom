SpanIndex = require '../span-index'
RunSpan = require './run-span'

class RunIndex extends SpanIndex

  constructor: (children) ->
    super(children)

  getRunCount: ->
    @spanCount

  getRun: (index) ->
    @getSpan(index)

  getRunIndex: (child) ->
    @getSpanIndex(child)

  getRuns: (start, count) ->
    @getSpans(start, count)

  iterateRuns: (start, count, operation) ->
    @iterateSpans(start, count, operation)

  insertRuns: (start, lines) ->
    @insertSpans(start, lines)

  removeRuns: (start, deleteCount) ->
    @removeSpans(start, deleteCount)

  sliceRunsToRange: (location, length) ->
    @sliceSpansToRange(location, length)

  createRun: (text) ->
    @createSpan(text)

  createSpan: (text) ->
    new RunSpan(text)

  ###
  Reading attributes
  ###

  getAttributesAtIndex: (characterIndex, effectiveRange, longestEffectiveRange) ->
    start = @getSpanInfoAtCharacterIndex(characterIndex)
    result = start.span.attributes

    if effectiveRange
      effectiveRange.location = start.spanLocation
      effectiveRange.length = start.span.getLength()

    if longestEffectiveRange
      @_longestEffectiveRange start.spanIndex, start.span, longestEffectiveRange, (run) ->
        _.isEqual(run.attributes, result)

    result

  getAttributeAtIndex: (attribute, characterIndex, effectiveRange, longestEffectiveRange) ->
    start = @getSpanInfoAtLocation(characterIndex)
    result = start.span.attributes[attribute]

    if effectiveRange
      effectiveRange.location = start.spanLocation
      effectiveRange.length = start.span.getLength()

    if longestEffectiveRange
      @_longestEffectiveRange start.spanIndex, start.span, longestEffectiveRange, (run) ->
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

    range.location = currentRun.getLocation()
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

    range.length = (currentRun.getLocation() + currentRun.getLength()) - range.location
    range

  ###
  Changing attributes
  ###

  sliceAndIterateRunsByRange: (location, length, operation) ->
    slice = @sliceRunsToRange(location, length)
    @iterateSpans(slice.spanIndex, slice.count, operation)

  setAttributesInRange: (attributes, location, length) ->
    @sliceAndIterateRunsByRange location, length, (run) ->
      run.setAttributes(attributes)

  addAttributeInRange: (attribute, value, location, length) ->
    @sliceAndIterateRunsByRange location, length, (run) ->
      run.addAttribute(attribute, value)

  addAttributesInRange: (attributes, location, length) ->
    @sliceAndIterateRunsByRange location, length, (run) ->
      run.addAttributes(attributes)

  removeAttributeInRange: (attribute, location, length) ->
    @sliceAndIterateRunsByRange location, length, (run) ->
      run.removeAttribute(attribute)

  ###
  Changing characters and attributes
  ###

  insertRunIndex: (runIndex, index) ->

module.exports = RunIndex