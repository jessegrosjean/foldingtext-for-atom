# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

AttributeRun = require './attribute-run'
Constants = require './Constants'
_ = require 'underscore-plus'
assert = require 'assert'
dom = require './dom'

# Public: A container holding both characters and formatting attributes.
#
# AttributedStrings have a limited public API. Right now they are mostly useful
# as containers for moving text and attributes from one {Item}'s body text to
# another item's body text. If you need to edit or list an item's text
# attributes use the item attribute methods instead:
#
# - {Item::getAttributedBodyTextSubstring}
# - {Item::getElementAtBodyTextIndex}
# - {Item::addElementInBodyTextRange}
# - {Item::removeElementInBodyTextRange}
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
  # Section: FTML
  #

  toInlineFTMLString: (ownerDocument=document) ->
    div = document.createElement 'div'
    div.appendChild @toInlineFTMLFragment(ownerDocument)
    div.innerHTML

  toInlineFTMLFragment: (ownerDocument=document) ->
    @_ensureClean()
    nodeRanges = AttributedString._calculateInitialNodeRanges @, ownerDocument
    nodeRangeStack = [
      start: 0
      end: @length
      node: ownerDocument.createDocumentFragment()
    ]
    AttributedString._buildFragmentFromNodeRanges nodeRanges, nodeRangeStack

  @_calculateInitialNodeRanges: (attributedString, ownerDocument) ->
    # For each attribute run create element nodes for each attribute and text node
    # for the text content. Store node along with range over which is should be
    # applied. Return sorted node ranages.
    string = attributedString.string()
    tagsToRanges = {}
    nodeRanges = []
    runIndex = 0

    for run in attributedString.attributeRuns()
      for tag, tagAttributes of run.attributes
        nodeRange = tagsToRanges[tag]
        if not nodeRange or nodeRange.end <= run.location
          assert(tag is tag.toUpperCase(), 'Tags Names Must be Uppercase')

          element = ownerDocument.createElement tag
          if tagAttributes
            for attrName, attrValue of tagAttributes
              element.setAttribute attrName, attrValue

          nodeRange =
            node: element
            start: run.location
            end: @_seekTagRangeEnd tag, tagAttributes, runIndex, attributedString

          tagsToRanges[tag] = nodeRange
          nodeRanges.push nodeRange

      text = string.substr run.location, run.length
      if text isnt Constants.ObjectReplacementCharacter and text isnt Constants.LineSeparatorCharacter
        nodeRanges.push
          start: run.location
          end: run.location + run.length
          node: ownerDocument.createTextNode(text)

      runIndex++

    nodeRanges.sort @_compareNodeRanges
    nodeRanges

  @_seekTagRangeEnd: (tagName, seekTagAttributes, runIndex, attributedString) ->
    attributeRuns = attributedString.attributeRuns()
    end = attributeRuns.length
    while true
      run = attributeRuns[runIndex++]
      runTagAttributes = run.attributes[tagName]
      equalAttributes = runTagAttributes is seekTagAttributes or _.isEqual(runTagAttributes, seekTagAttributes)
      unless equalAttributes
        return run.location
      else if runIndex is end
        return run.location + run.length

  @_compareNodeRanges: (a, b) ->
    if a.start < b.start
      -1
    else if a.start > b.start
      1
    else if a.end isnt b.end
      b.end - a.end
    else
      aNodeType = a.node.nodeType
      bNodeType = b.node.nodeType
      if aNodeType isnt bNodeType
        if aNodeType is Node.TEXT_NODE
          1
        else if bNodeType is Node.TEXT_NODE
          -1
        else
          aTagName = a.node.tagName
          bTagName = b.node.tagName
          if aTagName < bTagName
            -1
          else if aTagName > bTagName
            1
          else
            0
      else
        0

  @_buildFragmentFromNodeRanges: (nodeRanges, nodeRangeStack) ->
    i = 0
    while i < nodeRanges.length
      range = nodeRanges[i++]
      parentRange = nodeRangeStack.pop()
      while nodeRangeStack.length and parentRange.end <= range.start
        parentRange = nodeRangeStack.pop()

      if range.end > parentRange.end
        # In this case each has started inside current parent tag, but
        # extends past. Must split this node range into two. Process
        # start part of split here, and insert end part in correct
        # postion (after current parent) to be processed later.
        splitStart = range
        splitEnd =
          end: splitStart.end
          start: parentRange.end
          node: splitStart.node.cloneNode(true)
        splitStart.end = parentRange.end
        # Insert splitEnd after current parent in correct location.
        j = nodeRanges.indexOf parentRange
        while @_compareNodeRanges(nodeRanges[j], splitEnd) < 0
          j++
        nodeRanges.splice(j, 0, splitEnd)

      parentRange.node.appendChild range.node
      nodeRangeStack.push parentRange
      nodeRangeStack.push range

    nodeRangeStack[0].node

  InlineFTMLTags =
    # Inline text semantics
    'A': true
    'ABBR': true
    'B': true
    'BDI': true
    'BDO': true
    'BR': true
    'CITE': true
    'CODE': true
    'DATA': true
    'DFN': true
    'EM': true
    'I': true
    'KBD': true
    'MARK': true
    'Q': true
    'RP': true
    'RT': true
    'RUBY': true
    'S': true
    'SAMP': true
    'SMALL': true
    'SPAN': true
    'STRONG': true
    'SUB': true
    'SUP': true
    'TIME': true
    'U': true
    'VAR': true
    'WBR': true

    # Image & multimedia
    'AUDIO': true
    'IMG': true
    'VIDEO': true

    # Edits
    'DEL': true
    'INS': true

  @_addDOMNodeToAttributedString: (node, attributedString) ->
    nodeType = node.nodeType

    if nodeType is Node.TEXT_NODE
      attributedString.appendString(new AttributedString(node.nodeValue.replace(/(\r\n|\n|\r)/gm,'')))
    else if nodeType is Node.ELEMENT_NODE
      tagStart = attributedString.length
      each = node.firstChild

      if each
        while each
          @_addDOMNodeToAttributedString(each, attributedString)
          each = each.nextSibling
        if InlineFTMLTags[node.tagName]
          attributedString.addAttributeInRange(node.tagName, @_getElementAttributes(node), tagStart, attributedString.length - tagStart)
      else if InlineFTMLTags[node.tagName]
        if node.tagName is 'BR'
          lineBreak = new AttributedString(Constants.LineSeparatorCharacter)
          lineBreak.addAttributeInRange('BR', @_getElementAttributes(node), 0, 1)
          attributedString.appendString(lineBreak)
        else if node.tagName is 'IMG'
          image = new AttributedString(Constants.ObjectReplacementCharacter)
          image.addAttributeInRange('IMG', @_getElementAttributes(node), 0, 1)
          attributedString.appendString(image)

  @_getElementAttributes: (element) ->
    if element.hasAttributes()
      result = {}
      for each in element.attributes
        result[each.name] = each.value
      result
    else
      null

  @fromInlineFTMLString: (inlineFTMLString) ->
    div = document.createElement 'div'
    div.innerHTML = inlineFTMLString
    @fromInlineFTML div

  @fromInlineFTML: (inlineFTMLContainer) ->
    attributedString = new AttributedString()
    each = inlineFTMLContainer.firstChild
    while each
      @_addDOMNodeToAttributedString(each, attributedString)
      each = each.nextSibling
    attributedString

  @validateInlineFTML: (inlineFTMLContainer) ->
    end = dom.nodeNextBranch inlineFTMLContainer
    each = dom.nextNode inlineFTMLContainer
    while each isnt end
      if tagName = each.tagName
        assert.ok(InlineFTMLTags[tagName], "Unexpected tagName '#{tagName}' in 'P'")
      each = dom.nextNode each

  @inlineFTMLToText: (inlineFTMLContainer) ->
    if inlineFTMLContainer
      end = dom.nodeNextBranch(inlineFTMLContainer)
      each = dom.nextNode inlineFTMLContainer
      text = []

      while each isnt end
        nodeType = each.nodeType

        if nodeType is Node.TEXT_NODE
          text.push(each.nodeValue)
        else if nodeType is Node.ELEMENT_NODE and not each.firstChild
          tagName = each.tagName

          if tagName is 'BR'
            text.push(Constants.LineSeparatorCharacter)
          else if tagName is 'IMG'
            text.push(Constants.ObjectReplacementCharacter)
        each = dom.nextNode(each)
      text.join('')
    else
      ''

  @textOffsetToInlineFTMLOffset: (offset, inlineFTMLContainer) ->
    if inlineFTMLContainer
      end = dom.nodeNextBranch(inlineFTMLContainer)
      each = inlineFTMLContainer.firstChild or inlineFTMLContainer
      #each = inlineFTMLContainer

      while each isnt end
        nodeType = each.nodeType
        length = 0

        if nodeType is Node.TEXT_NODE
          length = each.nodeValue.length
        else if nodeType is Node.ELEMENT_NODE and not each.firstChild
          tagName = each.tagName

          if tagName is 'BR' or tagName is 'IMG'
            # Count void tags as 1
            length = 1
            if length is offset
              return {} =
                node: each.parentNode
                offset: dom.childIndexOfNode(each) + 1

        if length < offset
          offset -= length
        else
          #if downstreamAffinity and length is offset
          #  next = dom.nextNode(each)
          #  if next
          #    if next.nodeType is Node.ELEMENT_NODE and not next.firstChild
          #      each = next.parentNode
          #      offset = dom.childIndexOfNode(next)
          #    else
          #      each = next
          #      offset = 0
          return {} =
            node: each
            offset: offset
        each = dom.nextNode(each)
    else
      undefined

  @inlineFTMLOffsetToTextOffset: (node, offset, inlineFTMLContainer) ->
    unless inlineFTMLContainer
      # If inlineFTMLContainer is not provided then search up from node for
      # it. Search for 'P' tagname for model layer or 'contenteditable'
      # attribute for view layer.
      inlineFTMLContainer = node
      while inlineFTMLContainer and
            (inlineFTMLContainer.nodeType is Node.TEXT_NODE or
            not (inlineFTMLContainer.tagName is 'P' or
                 inlineFTMLContainer.hasAttribute?('contenteditable')))
        inlineFTMLContainer = inlineFTMLContainer.parentNode

    if node and inlineFTMLContainer and inlineFTMLContainer.contains(node)
      # If offset is > 0 and node is an element then map to child node
      # possition such that a backward walk from that node will cross over
      # all relivant text and void nodes.
      if offset > 0 and node.nodeType is Node.ELEMENT_NODE
        childAtOffset = node.firstChild
        while offset
          childAtOffset = childAtOffset.nextSibling
          offset--

        if childAtOffset
          node = childAtOffset
        else
          node = dom.lastDescendantNodeOrSelf(node.lastChild)

      # Walk backward to inlineFTMLContainer summing text characters and void
      # elements inbetween.
      each = node
      while each isnt inlineFTMLContainer
        nodeType = each.nodeType
        length = 0

        if nodeType is Node.TEXT_NODE
          if each isnt node
            offset += each.nodeValue.length
        else if nodeType is Node.ELEMENT_NODE and each.textContent.length is 0 and not each.firstElementChild
          tagName = each.tagName
          if tagName is 'BR' or tagName is 'IMG'
            # Count void tags as 1
            offset++
        each = dom.previousNode(each)
      offset
    else
      undefined

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
  # Section: Private
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
