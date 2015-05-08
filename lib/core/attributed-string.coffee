# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

AttributeRun = require './attribute-run'
_ = require 'underscore-plus'
assert = require 'assert'
Util = require './dom'

# Public: A text container holding both characters and formatting attributes.
#
# AttributedStrings are opaque and immutable. They are only useful for moving
# text and attributes from on {Item}s body text to another items body text.
# See:
#
# - {Item::getAttributedBodyTextSubstring}
# - {Item::replaceBodyTextInRange}
class AttributedString

  @fromTextOrAttributedString: (textOrAttributedString) ->
    if textOrAttributedString instanceof AttributedString
      textOrAttributedString.copy()
    else
      new AttributedString textOrAttributedString

  constructor: (string) ->
    string ?= ''
    @length = string.length
    @_string = string
    @_clean = false
    @_pendingAddAttributes = []

  attributesAtIndex: (index, effectiveRange, longestEffectiveRange) ->
    if index is -1
      index = @_string.length - location

    @_validateRange(index)
    @_ensureClean()

    runIndex = @_indexOfAttributeRunWithCharacterIndex(index)
    if runIndex is -1
      return null

    attributeRun = this.attributeRuns()[runIndex]
    if effectiveRange
      effectiveRange.location = attributeRun.location
      effectiveRange.length = attributeRun.length
      effectiveRange.end = attributeRun.location + attributeRun.length

    if longestEffectiveRange
      attributes = attributeRun.attributes
      @_longestEffectiveRange runIndex, attributeRun, longestEffectiveRange, (candiateRun) ->
        _.isEqual(candiateRun.attributes, attributes)
    attributeRun.attributes

  copy: ->
    @_ensureClean()
    theCopy = new AttributedString @_string
    attributeRuns = @attributeRuns()
    if attributeRuns
      attributeRunsCopy = []
      for each in attributeRuns
        attributeRunsCopy.push each.copy()
      theCopy._attributeRuns = attributeRunsCopy
    theCopy

  #
  # Section: String
  #

  string: (location, length) ->
    if location isnt undefined
      if length is -1
        length = @_string.length - location
      @_validateRange(location, length)
      @_string.substr(location, length)
    else
      return @_string

  deleteCharactersInRange: (location, length) ->
    @_validateAttributeRuns()

    if length is -1
      length = @_string.length - location

    @_validateRange(location, length)

    if length is 0
      return

    string = @_string
    deleteStart = location
    deleteEnd = deleteStart + length
    attributeRuns = @attributeRuns()
    attributeRunsLength = attributeRuns.length
    startingRunIndex = @_indexOfAttributeRunWithCharacterIndex(deleteStart)
    eachRunIndex = startingRunIndex

    while eachRunIndex < attributeRunsLength
      eachRun = attributeRuns[eachRunIndex]
      eachRunStart = eachRun.location
      eachRunEnd = eachRunStart + eachRun.length

      if deleteStart >= eachRunStart
        # adjust this runs length
        eachRun.length -= (Math.min(eachRunEnd, deleteEnd) - deleteStart)
      else if deleteEnd <= eachRunStart
        # adjust trailing run start location
        eachRun.location -= length
      else if deleteEnd < eachRunEnd
        # ajust this runs location and length
        eachRun.length -= (deleteEnd - eachRunStart)
        eachRun.location = deleteStart
      else
        # delete this run
        eachRun.length = 0

      # If run is empty and more runs exist, then delete this run. If more
      # runs don't exist then delete all attributes in remaining empy run.
      # In either case we'll advance to the next run.
      if eachRun.length is 0
        if attributeRunsLength > 0
          attributeRuns.splice(eachRunIndex, 1)
          attributeRunsLength--
        else
          eachRun.attributes = {}
          eachRunIndex++
      else
        eachRunIndex++

    @_string = string.substring(0, deleteStart) + string.substring(deleteEnd)
    @length = @_string.length

    @_clean = false
    @_validateAttributeRuns()

  insertStringAtLocation: (insertedString, location) ->
    @_validateAttributeRuns()

    if length is -1
      length = @_string.length - location

    @_validateRange(location)

    insertedAttributedString

    if insertedString instanceof AttributedString
      insertedAttributedString = insertedString
      insertedString = insertedAttributedString.string()

    if insertedString.length is 0
      return

    string = @_string
    attributeRuns = @attributeRuns()
    attributeRunsLength = attributeRuns.length
    startingRunIndex

    if location > 0
      startingRunIndex = @_indexOfAttributeRunWithCharacterIndex(location - 1)
    else
      startingRunIndex = @_indexOfAttributeRunWithCharacterIndex(location)

    if startingRunIndex is -1
      startingRunIndex = attributeRunsLength - 1

    startRun = attributeRuns[startingRunIndex]
    startRun.length += insertedString.length

    eachRunIndex = startingRunIndex + 1
    while eachRunIndex < attributeRunsLength
      eachRun = attributeRuns[eachRunIndex]
      eachRun.location += insertedString.length
      eachRunIndex++

    @_string = string.substring(0, location) + insertedString + string.substring(location)
    @length = @_string.length

    # If inserting an attributed string replace attributed runs covered by
    # the inserted with attribute runs from the original inserted string.
    if insertedAttributedString
      startReplaceRunsIndex = @_indexOfAttributeRunForCharacterIndex(location)
      endReplaceRunsIndex = @_indexOfAttributeRunForCharacterIndex(location + insertedString.length)
      insertedRuns = insertedAttributedString.attributeRuns()
      insertedRunsLength = insertedRuns.length

      if endReplaceRunsIndex is -1
        endReplaceRunsIndex = attributeRuns.length

      attributeRuns.splice(startReplaceRunsIndex, endReplaceRunsIndex - startReplaceRunsIndex)

      i = 0
      while i < insertedRunsLength
        eachInserted = insertedRuns[i].copy()
        eachInserted.location += location
        attributeRuns.splice(startReplaceRunsIndex, 0, eachInserted)
        startReplaceRunsIndex++
        i++

    @_clean = false
    @_validateAttributeRuns()

  appendString: (insertedString) ->
    @insertStringAtLocation(insertedString, @length)

  replaceCharactersInRange: (insertedString, location, length) ->
    @_validateAttributeRuns()

    if length is -1
      length = @_string.length - location

    @_validateRange(location, length)

    # The reason for this logic is so that inserted string gets attributes at
    # "location" if the inserted string doesn't contain it's own attributes.
    # The problem is if deleteCharactersInRange fully covers the range at
    # that location then those attributes will be removed before the insert
    # phase begins. So need to first copy them out into attributed string here.
    if not (insertedString instanceof AttributedString)
      insertedString = new AttributedString(insertedString)

      attributeRuns = @attributeRuns()
      attributeRunsLength = attributeRuns.length
      startingRunIndex

      if location > 0
        startingRunIndex = @_indexOfAttributeRunWithCharacterIndex(location - 1)
      else
        startingRunIndex = @_indexOfAttributeRunWithCharacterIndex(location)

      if startingRunIndex is -1
        startingRunIndex = attributeRunsLength - 1

      copyOfRunAtLocation = attributeRuns[startingRunIndex].copy()
      insertedString.attributeRuns()[0].attributes = copyOfRunAtLocation.attributes

    @deleteCharactersInRange(location, length)
    @insertStringAtLocation(insertedString, location)

  #
  # Section: Attributes
  #

  hasAttributes: ->
    return @_attributeRuns or (@_pendingAddAttributes and @_pendingAddAttributes.length > 0)

  attributeRuns: ->
    runs = @_attributeRuns
    pendingAddAttributes = @_pendingAddAttributes

    if not runs or runs.length is 0
      runs = [new AttributeRun(0, @_string.length, {})]
      @_attributeRuns = runs

    length = pendingAddAttributes.length
    if length
      @_pendingAddAttributes = []
      for eachPending in pendingAddAttributes
        @_addAttributeInRange(eachPending.attribute, eachPending.value, eachPending.location, eachPending.length)

    runs

  attributeAtIndex: (attribute, index, effectiveRange, longestEffectiveRange) ->
    if index is -1
      index = @_string.length - location

    @_validateRange(index)
    @_ensureClean()

    runIndex = @_indexOfAttributeRunWithCharacterIndex(index)
    if runIndex is -1
      return null

    attributeRun = @attributeRuns()[runIndex]
    if effectiveRange
      effectiveRange.location = attributeRun.location
      effectiveRange.length = attributeRun.length
      effectiveRange.end = attributeRun.location + attributeRun.length

    if longestEffectiveRange
      comparisonAttribute = attributeRun.attributes[attribute]
      @_longestEffectiveRange runIndex, attributeRun, longestEffectiveRange, (candiateRun) ->
        return candiateRun.attributes[attribute] is comparisonAttribute

    attributeRun.attributes[attribute]

  _longestEffectiveRange: (runIndex, attributeRun, longestEffectiveRange, shouldExtendRunToInclude) ->
    attributeRuns = @attributeRuns()
    length = attributeRuns.length
    nextIndex = runIndex - 1
    currentRun = attributeRun

    # scan backwards
    while nextIndex >= 0
      nextRun = attributeRuns[nextIndex]
      if shouldExtendRunToInclude(nextRun)
        currentRun = nextRun
        nextIndex--
      else
        break

    longestEffectiveRange.location = currentRun.location
    nextIndex = runIndex + 1
    currentRun = attributeRun

    # scan forwards
    while nextIndex < length
      nextRun = attributeRuns[nextIndex]
      if shouldExtendRunToInclude(nextRun)
        currentRun = nextRun
        nextIndex++
      else
        break

    longestEffectiveRange.length = (currentRun.location + currentRun.length) - longestEffectiveRange.location
    longestEffectiveRange.end = longestEffectiveRange.location + longestEffectiveRange.length

  #
  # Section: Changing Attributes
  #

  _addAttributeInRange: (attribute, value, location, length) ->
    @_validateAttributeRuns()

    if length is -1
      length = @_string.length - location

    @_validateRange(location, length)

    if length is 0
      return

    attributeRuns = @attributeRuns()
    startRunIndex = @_indexOfAttributeRunForCharacterIndex(location)
    endRunIndex = @_indexOfAttributeRunForCharacterIndex(location + length)
    i = startRunIndex

    if endRunIndex is -1
      endRunIndex = attributeRuns.length

    while i < endRunIndex
      attributeRuns[i].attributes[attribute] = value
      i++

    @_clean = false
    @_validateAttributeRuns()

  addAttributeInRange: (attribute, value, location, length) ->
    @_validateAttributeRuns()

    if length is -1
      length = @_string.length - location

    @_validateRange(location, length)

    if length is 0
      return

    @_pendingAddAttributes.push
      attribute: attribute
      value: value
      location: location
      length: length

    @_clean = false
    @_validateAttributeRuns()

  addAttributesInRange: (attributes, location, length) ->
    Object.keys(attributes).forEach (key) =>
      @addAttributeInRange(key, attributes[key], location, length)

  removeAttributeInRange: (attribute, location, length) ->
    if length is -1
      length = @_string.length - location

    @_validateRange(location, length)

    if length is 0 or not @hasAttributes()
      false
    else
      @removeAttributesInRange([attribute], location, length)

  removeAttributesInRange: (attributes, location, length) ->
    if length is -1
      length = @_string.length - location

    @_validateRange(location, length)
    @_validateAttributeRuns()

    if length is 0 or not @hasAttributes()
      return false

    didRemove = false
    attributeRuns = @attributeRuns()
    startRunIndex = if location is undefined then 0 else @_indexOfAttributeRunForCharacterIndex(location)
    endRunIndex = if location is undefined then -1 else @_indexOfAttributeRunForCharacterIndex(location + length)
    attributesLength = attributes.length
    i = startRunIndex

    if endRunIndex is -1
      endRunIndex = attributeRuns.length

    while i < endRunIndex
      attributeRunAttributes = attributeRuns[i].attributes
      for eachAttribute in attributes
        if attributeRunAttributes[eachAttribute] isnt undefined
          delete attributeRunAttributes[eachAttribute]
          didRemove = true
      i++

    if didRemove
      @_clean = false

    @_validateAttributeRuns()

    didRemove

  #
  # Section: Extract Substring
  #

  attributedSubstring: (location, length) ->
    if location isnt undefined
      if length is -1
        length = @_string.length - location
      @_validateRange(location, length)
    else
      return @copy()

    runs = @attributeRuns()
    startRunIndex = @_indexOfAttributeRunWithCharacterIndex(location)
    endRunIndex = @_indexOfAttributeRunWithCharacterIndex(location + length)
    substring = new AttributedString(@string(location, length))

    if endRunIndex is -1
      endRunIndex = runs.length - 1

    selectedRuns = runs.slice(startRunIndex, endRunIndex + 1)

    substring._attributeRuns = selectedRuns.map((eachRun) ->
      eachRunCopy = eachRun.copy()
      eachRunStart = eachRunCopy.location

      if eachRunStart < location
        eachRunCopy.length -= (location - eachRunStart)
        eachRunCopy.location = 0
      else
        eachRunCopy.location -= location

      eachRunEnd = eachRunCopy.location + eachRunCopy.length
      if eachRunEnd > length
        eachRunCopy.length -= (eachRunEnd - length)

      return eachRunCopy
    ).filter (eachRun) ->
      return eachRun.length > 0

    substring._validateAttributeRuns()

    substring

  #
  # Section: Debug
  #

  toString: (showAttributeValues) ->
    @_ensureClean()

    string = @_string
    attributeRuns = @attributeRuns()
    length = attributeRuns.length
    results = []

    for eachRun in attributeRuns
      eachRunAttributes = eachRun.attributes

      sortedNames = []
      for eachName, eachValue of eachRunAttributes
        if eachValue isnt undefined
          sortedNames.push(eachName)
      sortedNames.sort()

      nameValues = []
      for eachName in sortedNames
        if showAttributeValues
          nameValues.push(eachName + '=' + JSON.stringify(eachRunAttributes[eachName]))
        else
          nameValues.push(eachName)

      results.push(string.substr(eachRun.location, eachRun.length) + '/' + nameValues.join(', '))

    '(' + results.join(')(') + ')'

  #
  # Private
  #

  _ensureClean: ->
    if @_clean
      return

    attributeRuns = @attributeRuns()
    previousAttributeRun = attributeRuns[0]
    length = attributeRuns.length
    i = 1

    while i < length
      attributeRun = attributeRuns[i]
      if previousAttributeRun._mergeWithNext(attributeRun)
        attributeRuns.splice(i, 1)
        length--
      else
        previousAttributeRun = attributeRun
        i++

    @_clean = true

  _indexOfAttributeRunWithCharacterIndex: (characterIndex) ->
    assert.ok(characterIndex >= 0 or characterIndex <= @_string.length, 'Invalid character index')

    attributeRuns = @attributeRuns()
    low = 0
    high = attributeRuns.length - 1
    result = -1

    while low <= high
      i = (low + high) >> 1
      run = attributeRuns[i]
      location = run.location
      length = run.length
      end = location + length

      if characterIndex >= location and characterIndex < end
        result = i
        break
      else if end <= characterIndex
        low = i + 1
        continue
      else
        high = i - 1
        continue

    result

  #
  # Section: Private
  #

  _indexOfAttributeRunForCharacterIndex: (characterIndex) ->
    runIndex = @_indexOfAttributeRunWithCharacterIndex(characterIndex)

    if runIndex is -1
      return -1

    attributeRuns = @attributeRuns()
    attributeRun = attributeRuns[runIndex]
    location = attributeRun.location
    length = attributeRun.length

    if location is characterIndex
      return runIndex

    newAttributeRun = attributeRun.splitAtIndex(characterIndex)
    attributeRuns.splice(runIndex + 1, 0, newAttributeRun)
    runIndex + 1

  _validateRange: (location, length) ->
    assert.ok(location >= 0 and location <= @_string.length, 'Invalid location')
    if length
      assert.ok(length >= 0, 'Length must be positive')
      assert.ok(location + length <= @_string.length, 'Length must not be beyond string')

  _validateAttributeRuns: ->
    if true
      attributeRuns = @attributeRuns()

      if attributeRuns
        length = attributeRuns.length

        if length
          offset = 0
          for eachRun in attributeRuns
            assert.ok(eachRun.location >= 0, 'Location must be postive')
            assert.ok(eachRun.location <= @_string.length, 'Location must be less then or equal to end of string')
            assert.ok(eachRun.location + eachRun.length <= @_string.length, 'Location + length must be less then or equal to end of string')

            if length > 1
              assert.ok(eachRun.length > 0, 'Attribute Run Empty')

            assert.ok(eachRun.location is offset, 'Attribute Run Invalid Location')
            offset += eachRun.length

          assert.ok(offset is @_string.length, 'Attribute Run Invalid Location')
        else
          assert.ok(false, 'Empty Attribute Runs')

module.exports = AttributedString