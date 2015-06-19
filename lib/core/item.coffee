# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

AttributedString = require './attributed-string'
Constants = require './constants'
Mutation = require './mutation'
ItemPath = require './item-path'
UrlUtil = require './url-util'
_ = require 'underscore-plus'
assert = require 'assert'

# Essential: A paragraph of text in an {Outline}.
#
# Items cannot be instantiated directly, instead use {Outline::createItem}.
#
# Items may contain other child items to form a hierarchical outline structure.
# When you move an item all of its children are moved with it.
#
# Items have a single paragraph of body text. You can access it as plain text,
# a HTML string, or an {AttributedString}. You can add formatting to make parts
# of the text bold, italic, etc.
#
# You can assign item level attributes to items. For example you might store a
# due date in the `data-due-date` attribute. Or store an item type in the
# `data-type` attribute.
#
# ## Examples
#
# Create Items:
#
# ```coffeescript
# item = outline.createItem('Hello World!')
# outline.root.appendChild(item)
# ```
#
# Add body text formatting:
#
# ```coffeescript
# item = outline.createItem('Hello World!')
# item.addElementInBodyTextRange('B', {}, 6, 5)
# item.addElementInBodyTextRange('I', {}, 0, 11)
# ```
#
# Read body text formatting:
#
# ```coffeescript
# effectiveRange = end: 0
# textLength = item.bodyText.length
# while effectiveRange.end < textLength
#   console.log item.getElementsAtBodyTextIndex effectiveRange.end, effectiveRange
#```
module.exports =
class Item

  constructor: (outline, text, liOrRootUL, remappedIDCallback) ->
    tagName = liOrRootUL.tagName
    if tagName is 'LI'
      p = liOrRootUL.firstChild
      pOrUL = liOrRootUL.lastChild
      pTagName = p?.tagName
      pOrULTagName = pOrUL?.tagName
      assert.ok(pTagName is 'P', "Expected 'P', but got #{pTagName}")
      if pTagName is pOrULTagName
        assert.ok(pOrUL is p, "Expect single 'P' child in 'LI'")
      else
        assert.ok(pOrULTagName is 'UL', "Expected 'UL', but got #{pOrULTagName}")
        assert.ok(pOrUL.previousSibling is p, "Expected previous sibling of 'UL' to be 'P'")

      AttributedString.validateInlineFTML(p)
    else if tagName is 'UL'
      assert.ok(liOrRootUL.id is Constants.RootID)
    else
      assert.ok(false, "Expected 'LI' or 'UL', but got #{tagName}")

    @outline = outline
    @_liOrRootUL = liOrRootUL
    @_bodyAttributedString = null
    liOrRootUL._item = this

    if ul = _childrenUL(liOrRootUL, false)
      childLI = ul.firstChild
      while childLI
        outline.createItem(null, childLI, remappedIDCallback)
        childLI = childLI.nextSibling

    if text
      if text instanceof AttributedString
        @attributedBodyText = text
      else
        _bodyP(liOrRootUL).textContent = text

    originalID = liOrRootUL.id
    assignedID = outline.nextOutlineUniqueItemID(originalID)

    if originalID isnt assignedID
      liOrRootUL.id = assignedID
      if remappedIDCallback and originalID
        remappedIDCallback(originalID, assignedID, this)

  ###
  Section: Attributes
  ###

  # Public: Read-only unique and persistent {String} item ID.
  id: null
  Object.defineProperty @::, 'id',
    get: -> @_liOrRootUL.id

  # Public: Read-only {Array} of this item's attribute names.
  attributeNames: null
  Object.defineProperty @::, 'attributeNames',
    get: ->
      namedItemMap = @_liOrRootUL.attributes
      length = namedItemMap.length
      attributeNames = []

      for i in [0..length - 1] by 1
        name = namedItemMap[i].name
        if name isnt 'id'
          attributeNames.push(name)

      attributeNames

  # Public: Test to see if this item has an attribute with the given name.
  #
  # - `name` The {String} attribute name.
  #
  # Returns a {Boolean}
  hasAttribute: (name) ->
    @_liOrRootUL.hasAttribute(name)

  # Public: Get the value of the specified attribute. If the attribute does
  # not exist will return `undefined`.
  #
  # - `name` The {String} attribute name.
  # - `array` (optional) {Boolean} true if should split comma separated value to create an array.
  # - `clazz` (optional) {Class} ({Number} or {Date}) to convert string values into.
  #
  # Returns attribute value.
  getAttribute: (name, array, clazz) ->
    value
    if value = @_liOrRootUL.getAttribute name
      if array
        value = value.split /\s*,\s*/
        if clazz
          value = (Item.attributeValueStringToObject(each, clazz) for each in value)
      else if clazz
        value = Item.attributeValueStringToObject value, clazz
    value

  # Public: Adds a new attribute or changes the value of an existing
  # attribute. `id` is reserved and an exception is thrown if you try to set
  # it. Non string values (such as {Date}s) will be converted to appropriate
  # string format so that they can be read back using {::getAttribute()}.
  # Setting an attribute to `null` or `undefined` will remove the attribute.
  #
  # - `name` The {String} attribute name.
  # - `value` The new attribute value.
  setAttribute: (name, value) ->
    assert.ok(name isnt 'id', 'id is reserved attribute name')

    value = Item.objectToAttributeValueString value
    oldValue = @getAttribute name or undefined

    if value is oldValue
      return

    outline = @outline
    isInOutline = @isInOutline
    if isInOutline
      mutation = Mutation.createAttributeMutation this, name, oldValue
      outline.emitter.emit 'will-change', mutation
      outline.beginUpdates()
      outline.recoredUpdateMutation mutation

    if value?
      @_liOrRootUL.setAttribute name, value
    else
      @_liOrRootUL.removeAttribute name

    if isInOutline
      outline.endUpdates()

  # Public: Removes an attribute from the specified item. Attempting to remove
  # an attribute that is not on the item doesn't raise an exception.
  #
  # - `name` The {String} attribute name.
  removeAttribute: (name) ->
    if @hasAttribute name
      @setAttribute name, undefined

  @attributeValueStringToObject: (value, clazz) ->
    switch clazz
      when Number
        parseFloat value
      when Date
        new Date value
      else
        value

  @objectToAttributeValueString: (object) ->
    if _.isString object
      object
    else if _.isDate object
      object.toISOString()
    else if _.isArray object
      (Item.objectToAttributeValueString(each) for each in object).join ','
    else if object
      object.toString()
    else
      object

  ###
  Section: User Data
  ###

  getUserData: (userKey) ->
    @userData?[userKey]

  setUserData: (userKey, userData) ->
    unless @userData
      @userData = {}

    if userData is undefined
      delete @userData[userKey]
    else
      @userData[userKey] = userData

  ###
  Section: Body Text
  ###

  # Public: Read-only true if this item has body text
  hasBodyText: null
  Object.defineProperty @::, 'hasBodyText',
    get: -> _bodyP(@_liOrRootUL).innerHTML.length > 0

  # Public: Body text as plain text {String}.
  bodyText: null
  Object.defineProperty @::, 'bodyText',
    get: ->
      # Avoid creating attributed string if not already created. Syntax
      # highlighting will call this method for each displayed node, so try
      # to make it fast.
      if @_bodyAttributedString
        @_bodyAttributedString.string()
      else
        AttributedString.inlineFTMLToText _bodyP(@_liOrRootUL)
    set: (text) ->
      @replaceBodyTextInRange text, 0, @bodyText.length

  # Public: Body text as HTML {String}.
  bodyHTML: null
  Object.defineProperty @::, 'bodyHTML',
    get: -> _bodyP(@_liOrRootUL).innerHTML
    set: (html) ->
      p = @_liOrRootUL.ownerDocument.createElement 'P'
      p.innerHTML = html
      @attributedBodyText = AttributedString.fromInlineFTML(p)

  # Public: Body text as {AttributedString}.
  attributedBodyText: null
  Object.defineProperty @::, 'attributedBodyText',
    get: ->
      if @isRoot
        return new AttributedString
      @_bodyAttributedString ?= AttributedString.fromInlineFTML(_bodyP(@_liOrRootUL))

    set: (attributedText) ->
      @replaceBodyTextInRange attributedText, 0, @bodyText.length

  # Public: Returns an {AttributedString} substring of this item's body text.
  #
  # - `location` Substring's strart location.
  # - `length` Length of substring to extract.
  getAttributedBodyTextSubstring: (location, length) ->
    @attributedBodyText.attributedSubstring(location, length)

  # Public: Looks to see if there's an element with the given `tagName` at the
  # given index. If there is then that element's attributes are returned and
  # by reference the range over which the element applies.
  #
  # - `tagName` Tag name of the element.
  # - `index` The character index.
  # - `effectiveRange` (optional) {Object} whose `location` and `length`
  #    properties will be set to effective range of element.
  # - `longestEffectiveRange` (optional) {Object} whose `location` and `length`
  #    properties will be set to longest effective range of element.
  #
  # Returns elements attribute values as an {Object} or {undefined}
  getElementAtBodyTextIndex: (tagName, index, effectiveRange, longestEffectiveRange) ->
    assert(tagName is tagName.toUpperCase(), 'Tag Names Must be Uppercase')
    @attributedBodyText.attributeAtIndex(
      tagName,
      index,
      effectiveRange,
      longestEffectiveRange
    )

  # Public: Returns an {Object} with keys for each element at the given
  # character index, and by reference the range over which the elements apply.
  #
  # - `index` The character index.
  # - `effectiveRange` (optional) {Object} whose `location` and `length`
  #    properties will be set to effective range of element.
  # - `longestEffectiveRange` (optional) {Object} whose `location` and `length`
  #    properties will be set to longest effective range of element.
  getElementsAtBodyTextIndex: (index, effectiveRange, longestEffectiveRange) ->
    @attributedBodyText.attributesAtIndex(
      index,
      effectiveRange,
      longestEffectiveRange
    )

  # Public: Adds an element with the given tagName and attributes to the
  # characters in the specified range.
  #
  # - `tagName` Tag name of the element.
  # - `attributes` Element attributes. Use `null` as a placeholder if element
  #    doesn't need attributes.
  # - `location` Start location character index.
  # - `length` Range length.
  addElementInBodyTextRange: (tagName, attributes, location, length) ->
    elements = {}
    elements[tagName] = attributes
    @addElementsInBodyTextRange(elements, location, length)

  addElementsInBodyTextRange: (elements, location, length) ->
    for eachTagName of elements
      assert(
        eachTagName is eachTagName.toUpperCase(),
        'Tag Names Must be Uppercase'
      )
    changedText = @getAttributedBodyTextSubstring(location, length)
    changedText.addAttributesInRange(elements, 0, length)
    @replaceBodyTextInRange(changedText, location, length)

  # Public: Removes the element with the tagName from the characters in the
  # specified range.
  #
  # - `tagName` Tag name of the element.
  # - `location` Start location character index.
  # - `length` Range length.
  removeElementInBodyTextRange: (tagName, location, length) ->
    assert(tagName is tagName.toUpperCase(), 'Tag Names Must be Uppercase')
    @removeElementsInBodyTextRange([tagName], location, length)

  removeElementsInBodyTextRange: (tagNames, location, length) ->
    for eachTagName in tagNames
      assert(
        eachTagName is eachTagName.toUpperCase(),
        'Tag Names Must be Uppercase'
      )
    changedText = @getAttributedBodyTextSubstring(location, length)
    changedText.removeAttributesInRange(tagNames, 0, length)
    @replaceBodyTextInRange(changedText, location, length)

  insertLineBreakInBodyText: (location) ->

  insertImageInBodyText: (location, image) ->

  # Public: Replace body text in the given range.
  #
  # - `insertedText` {String} or {AttributedString}
  # - `location` Start location character index.
  # - `length` Range length.
  replaceBodyTextInRange: (insertedText, location, length) ->
    if @isRoot
      return

    attributedBodyText = @attributedBodyText
    isInOutline = @isInOutline
    outline = @outline
    insertedString

    if insertedText instanceof AttributedString
      insertedString = insertedText.string()
    else
      insertedString = insertedText

    assert.ok(
      insertedString.indexOf('\n') is -1,
      'Item body text cannot contain newlines'
    )

    if isInOutline
      undoManager = outline.undoManager
      replacedText

      if length
        replacedText = attributedBodyText.attributedSubstring(location, length)
      else
        replacedText = new AttributedString

      mutation = Mutation.createBodyTextMutation this, location, insertedString.length, replacedText
      outline.emitter.emit 'will-change', mutation
      outline.beginUpdates()
      outline.recoredUpdateMutation mutation

    li = @_liOrRootUL
    bodyP = _bodyP(li)
    attributedBodyText = @attributedBodyText
    ownerDocument = li.ownerDocument
    attributedBodyText.replaceCharactersInRange(insertedText, location, length)
    newBodyPContent = attributedBodyText.toInlineFTMLFragment(ownerDocument)
    newBodyP = ownerDocument.createElement('P')
    newBodyP.appendChild(newBodyPContent)
    li.replaceChild(newBodyP, bodyP)

    if isInOutline
      outline.endUpdates()

  # Public: Append body text.
  #
  # - `text` {String} or {AttributedString}
  # - `elements` (optional) {Object} whose keys are formatting element
  #   tagNames and values are attributes for those elements. If specified the
  #   appended text will include these elements.
  appendBodyText: (text, elements) ->
    if elements
      unless text instanceof AttributedString
        text = new AttributedString text
      text.addAttributesInRange elements, 0, text.length
    @replaceBodyTextInRange text, @bodyText.length, 0

  ###
  Section: Outline Structure
  ###

  # Public: Read-only true if is root {Item}.
  isRoot: null
  Object.defineProperty @::, 'isRoot',
    get: -> @id is Constants.RootID

  # Public: Read-only {Boolean} true if this item has no body text and no
  # attributes and no children.
  isEmpty: null
  Object.defineProperty @::, 'isEmpty',
    get: ->
      not @hasBodyText and
      not @firstChild and
      @attributeNames.length is 0

  # Public: Read-only true if item is part of owning {Outline}
  isInOutline: null
  Object.defineProperty @::, 'isInOutline',
    get: ->
      li = @_liOrRootUL
      li.ownerDocument.contains(li);

  # Public: Read-only root {Item}.
  root: null
  Object.defineProperty @::, 'root',
    get: ->
      if @isInOutline
        @outline.root
      else
        each = this
        while each.parent
          each = each.parent;
        each

  # Public: Read-only depth of {Item} in outline structure.
  depth: null
  Object.defineProperty @::, 'depth',
    get: ->
      depth = 0
      ancestor = @parent
      while ancestor
        ancestor = ancestor.parent
        depth++
      depth

  # Public: Read-only parent {Item}.
  parent: null
  Object.defineProperty @::, 'parent',
    get: -> _parentLIOrRootUL(@_liOrRootUL)?._item

  # Public: Read-only first child {Item}.
  firstChild: null
  Object.defineProperty @::, 'firstChild',
    get: -> _childrenUL(@_liOrRootUL, false)?.firstChild?._item

  # Public: Read-only last child {Item}.
  lastChild: null
  Object.defineProperty @::, 'lastChild',
    get: -> _childrenUL(@_liOrRootUL, false)?.lastChild?._item

  # Public: Read-only previous sibling {Item}.
  previousSibling: null
  Object.defineProperty @::, 'previousSibling',
    get: -> @_liOrRootUL.previousSibling?._item

  # Public: Read-only next sibling {Item}.
  nextSibling: null
  Object.defineProperty @::, 'nextSibling',
    get: -> @_liOrRootUL.nextSibling?._item

  # Public: Read-only previous branch {Item}.
  previousBranch: null
  Object.defineProperty @::, 'previousBranch',
    get: -> @previousSibling or @previousItem

  # Public: Read-only next branch {Item}.
  nextBranch: null
  Object.defineProperty @::, 'nextBranch',
    get: -> @lastDescendantOrSelf.nextItem

  # Public: Read-only {Array} of ancestor {Items}.
  ancestors: null
  Object.defineProperty @::, 'ancestors',
    get: ->
      ancestors = []
      each = @parent
      while each
        ancestors.unshift(each)
        each = each.parent
      ancestors

  # Public: Read-only {Array} of descendant {Items}.
  descendants: null
  Object.defineProperty @::, 'descendants',
    get: ->
      descendants = []
      end = @nextBranch
      each = @nextItem
      while each isnt end
        descendants.push(each)
        each = each.nextItem
      return descendants

  # Public: Read-only last descendant {Item}.
  lastDescendant: null
  Object.defineProperty @::, 'lastDescendant',
    get: ->
      each = @lastChild
      while each?.lastChild
        each = each.lastChild
      each

  Object.defineProperty @::, 'lastDescendantOrSelf',
    get: -> @lastDescendant or this

  # Public: Read-only previous {Item} in the outline.
  previousItem: null
  Object.defineProperty @::, 'previousItem',
    get: ->
      previousSibling = @previousSibling
      if previousSibling
        previousSibling.lastDescendantOrSelf
      else
        parent = @parent
        if not parent or parent.isRoot
          null
        else
          parent

  Object.defineProperty @::, 'previousItemOrRoot',
    get: -> @previousItem or @parent

  # Public: Read-only next {Item} in the outline.
  nextItem: null
  Object.defineProperty @::, 'nextItem',
    get: ->
      firstChild = @firstChild
      if firstChild
        return firstChild

      nextSibling = @nextSibling
      if nextSibling
        return nextSibling

      parent = @parent
      while parent
        nextSibling = parent.nextSibling
        if nextSibling
          return nextSibling
        parent = parent.parent

      null

  # Public: Read-only has children {Boolean}.
  hasChildren: null
  Object.defineProperty @::, 'hasChildren',
    get: ->
      ul = _childrenUL(@_liOrRootUL)
      if ul
        ul.hasChildNodes()
      else
        false

  # Public: Read-only {Array} of child {Items}.
  children: null
  Object.defineProperty @::, 'children',
    get: ->
      children = []
      each = @firstChild
      while each
        children.push(each)
        each = each.nextSibling
      children

  # Public: Determines if this item contains the given item.
  #
  # - `item` The {Item} to check for containment.
  #
  # Returns {Boolean}.
  contains: (item) ->
    @_liOrRootUL.contains(item._liOrRootUL)

  # Public: Compares the position of this item against another item in the
  # outline. See
  # [Node.compareDocumentPosition()](https://developer.mozilla.org/en-
  # US/docs/Web/API/Node.compareDocumentPosition) for more information.
  #
  # - `item` The {Item} to compare against.
  #
  # Returns a {Number} bitmask.
  comparePosition: (item) ->
    @_liOrRootUL.compareDocumentPosition(item._liOrRootUL)

  # Public: Deep clones this item.
  #
  # Returns a duplicate {Item}.
  cloneItem: (remappedIDCallback) ->
    @outline.cloneItem(this, remappedIDCallback)

  # Public: Given an array of items determines and returns the common
  # ancestors of those items.
  #
  # - `items` {Array} of {Items}.
  #
  # Returns a {Array} of common ancestor {Items}.
  @getCommonAncestors: (items) ->
    commonAncestors = []
    itemIDs = {}

    for each in items
      itemIDs[each.id] = true

    for each in items
      p = each.parent
      while p and not itemIDs[p.id]
        p = p.parent
      unless p
        commonAncestors.push each

    commonAncestors

  @itemsWithAncestors: (items) ->
    ancestorsAndItems = []
    addedIDs = {}

    for each in items
      index = ancestorsAndItems.length
      while each
        if addedIDs[each.id]
          continue
        else
          ancestorsAndItems.splice(index, 0, each)
          addedIDs[each.id] = true
        each = each.parent

    ancestorsAndItems

  ###
  Section: Mutating Outline Structure
  ###

  # Public: Insert the new child item before the referenced sibling in this
  # item's list of children. If referenceSibling isn't defined the item is
  # inserted at the end.
  #
  # - `child` The inserted child {Item} .
  # - `referenceSibling` (optional) The referenced sibling {Item} .
  insertChildBefore: (child, referenceSibling) ->
    @insertChildrenBefore([child], referenceSibling)

  # Public: Insert the new children before the referenced sibling in this
  # item's list of children. If referenceSibling isn't defined the new
  # children are inserted at the end.
  #
  # - `children` {Array} of {Item}s to insert.
  # - `referenceSibling` (optional) The referenced sibling {Item}.
  insertChildrenBefore: (children, referenceSibling) ->
    isInOutline = @isInOutline
    outline = @outline

    outline.removeItemsFromParents(children)

    if isInOutline
      previousSibling = null
      if referenceSibling
        previousSibling = referenceSibling.previousSibling
      else
        previousSibling = @lastChild

      mutation = Mutation.createChildrenMutation this, children, [], previousSibling, referenceSibling
      outline.emitter.emit 'will-change', mutation
      outline.beginUpdates()
      outline.recoredUpdateMutation mutation

    ownerDocument = @_liOrRootUL.ownerDocument
    documentFragment = ownerDocument.createDocumentFragment()
    referenceSiblingLI = referenceSibling?._liOrRootUL
    childrenUL = _childrenUL(@_liOrRootUL, true)

    for each in children
      assert.ok(
        each._liOrRootUL.ownerDocument is ownerDocument,
        'children must share same owner document'
      )
      documentFragment.appendChild(each._liOrRootUL)

    childrenUL.insertBefore(documentFragment, referenceSiblingLI)

    if isInOutline
      outline.endUpdates()

  # Public: Append the new children to this item's list of children.
  #
  # - `children` The children {Array} to append.
  appendChildren: (children) ->
    @insertChildrenBefore(children, null)

  # Public: Append the new child to this item's list of children.
  #
  # - `child` The child {Item} to append.
  appendChild: (child) ->
    @insertChildrenBefore([child], null)

  # Public: Remove the children from this item's list of children.
  #
  # - `children` The {Array} of children {Items}s to remove.
  removeChildren: (children) ->
    if not children.length
      return

    isInOutline = @isInOutline
    outline = @outline

    if isInOutline
      lastChild = children[children.length - 1]
      nextSibling = lastChild.nextSibling
      mutation = Mutation.createChildrenMutation this, [], children, children[0].previousSibling, nextSibling
      outline.emitter.emit 'will-change', mutation
      outline.beginUpdates()
      outline.recoredUpdateMutation mutation

    for each in children
      each._liOrRootUL.parentNode.removeChild(each._liOrRootUL)

    if isInOutline
      outline.endUpdates()

  # Public: Remove the given child from this item's list of children.
  #
  # - `child` The child {Item} to remove.
  removeChild: (child) ->
    @removeChildren([child])

  # Public: Remove this item from it's parent item if it has a parent.
  removeFromParent: ->
    @parent?.removeChild(this)

  ###
  Section: Querying Outline Structure
  ###

  evaluateItemPath: (itemPath, options) ->
    ItemPath.evaluate itemPath, this, options

  evaluateXPath: (xpathExpression, namespaceResolver, resultType, result) ->
    @outline.evaluateXPath(xpathExpression, this, namespaceResolver, resultType, result)

  getItemsForXPath: (xpathExpression, namespaceResolver, exceptionCallback) ->
    @outline.getItemsForXPath(xpathExpression, this, namespaceResolver, exceptionCallback)

  ###
  Section: Debug
  ###

  # Extended: Returns debug string for this branch.
  branchToString: (indent) ->
    indent ?= ''
    results = [@toString(indent)]
    for each in @children
      results.push(each.branchToString(indent + '    '))
    results.join('\n')

  # Extended: Returns debug HTML string for this branch.
  branchToHTML: ->
    @_liOrRootUL.outerHTML

  # Extended: Returns debug string for this item.
  toString: (indent) ->
    (indent or '') + '(' + @id + ') ' + @bodyHTML

###
Section: Util Functions
###

_parentLIOrRootUL = (liOrRootUL) ->
  parentNode = liOrRootUL.parentNode
  while parentNode
    if parentNode._item
      return parentNode
    parentNode = parentNode.parentNode

_bodyP = (liOrRootUL) ->
  if liOrRootUL.tagName is 'UL'
    # In case of root element just return an empty disconnected P for api
    # compatibilty.
    assert.ok(liOrRootUL.id is Constants.RootID)
    liOrRootUL.ownerDocument.createElement('p')
  else
    liOrRootUL.firstChild

_childrenUL = (liOrRootUL, createIfNeeded) ->
  if liOrRootUL.tagName is 'UL'
    assert.ok(liOrRootUL.id is Constants.RootID)
    liOrRootUL
  else
    ul = liOrRootUL.lastChild
    tagName = ul?.tagName
    if tagName is 'UL'
      ul
    else if tagName is 'P'
      if createIfNeeded
        ul = liOrRootUL.ownerDocument.createElement('UL')
        liOrRootUL.appendChild(ul)
        ul
    else if tagName
      assert.ok(false, "Invalid HTML, expected #{tagName} to be 'P' or 'UL'")
