# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

AttributedString = require './attributed-string-ftml'
Constants = require './constants'
ItemPath = require './item-path'
Mutation = require './mutation'
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
# item.addBodyTextAttributeInRange('B', {}, 6, 5)
# item.addBodyTextAttributeInRange('I', {}, 0, 11)
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

  constructor: (outline, text, id, remappedIDCallback) ->
    @id = outline.nextOutlineUniqueItemID(id)
    @outline = outline
    @inOutline = false
    @attributedString = new AttributedString(text)
    if id isnt @id
      if remappedIDCallback and id
        remappedIDCallback(id, @id, this)

  ###
  Section: Attributes
  ###

  # Public: Read-only unique and persistent {String} item ID.
  id: null

  # Public: Read-only {Outline} this item belongs to.
  outline: null

  # Public: Read-only {Boolean} is this item contained by outline root.
  inOutline: null

  # Public: Read-only attribute key/value object
  attributes: null

  # Public: Read-only {Array} of this item's attribute names.
  attributeNames: null
  Object.defineProperty @::, 'attributeNames',
    get: ->
      if @attributes
        Object.keys(@attributes)
      else
        []

  # Public: Test to see if this item has an attribute with the given name.
  #
  # - `name` The {String} attribute name.
  #
  # Returns a {Boolean}
  hasAttribute: (name) ->
    @attributes?[name]?

  # Public: Get the value of the specified attribute. If the attribute does
  # not exist will return `null`.
  #
  # - `name` The {String} attribute name.
  # - `array` (optional) {Boolean} true if should split comma separated string value to create an array.
  # - `clazz` (optional) {Class} ({Number} or {Date}) to parse string values to objects of given class.
  #
  # Returns attribute value.
  getAttribute: (name, array, clazz) ->
    if value = @attributes?[name]
      if array and _.isString(value)
        value = value.split /\s*,\s*/
        if clazz
          value = (Item.attributeValueStringToObject(each, clazz) for each in value)
      else if clazz and _.isString(value)
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

    oldValue = @getAttribute name

    if value is oldValue
      return

    outline = @outline
    isInOutline = @isInOutline
    if isInOutline
      mutation = Mutation.createAttributeMutation this, name, oldValue
      outline.emitter.emit 'will-change', mutation
      outline.beginChanges()
      outline.recordChange mutation

    if value?
      unless @attributes
        @attributes = {}
      @attributes[name] = value
    else
      if @attributes
        delete @attributes[name]

    outline.syncAttributeToBodyText(this, name, value, oldValue)

    if isInOutline
      outline.emitter.emit 'did-change', mutation
      outline.endChanges()

  # Public: Removes an attribute from the specified item. Attempting to remove
  # an attribute that is not on the item doesn't raise an exception.
  #
  # - `name` The {String} attribute name.
  removeAttribute: (name) ->
    if @hasAttribute name
      @setAttribute name, null

  @attributeValueStringToObject: (value, clazz) ->
    switch clazz
      when Number
        parseFloat value
      when Date
        new Date value
      else
        value

  @objectToAttributeValueString: (object) ->
    if _.isNumber object
      object.toString()
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

  userData: null

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

  attributedString: null

  # Public: Body text as plain text {String}.
  bodyText: null
  Object.defineProperty @::, 'bodyText',
    get: ->
      @attributedString.string.toString()
    set: (text='') ->
      @replaceBodyTextInRange text, 0, @bodyTextLength

  # Public: Body text length.
  bodyTextLength: null
  Object.defineProperty @::, 'bodyTextLength',
    get: ->
      @attributedString.string.length

  # Public: Body as HTML {String}.
  bodyHTML: null
  Object.defineProperty @::, 'bodyHTML',
    get: -> @attributedBodyText.toInlineFTMLString()
    set: (html) ->
      p = document.createElement 'P'
      p.innerHTML = html
      @attributedBodyText = AttributedString.fromInlineFTML(p)

  # Public: Body text as read-only {AttributedString}.
  attributedBodyText: null
  Object.defineProperty @::, 'attributedBodyText',
    get: ->
      if @isRoot
        return new AttributedString
      @attributedString
    set: (attributedText) ->
      @replaceBodyTextInRange attributedText, 0, @bodyTextLength

  # Public: Returns an {AttributedString} substring of this item's body text.
  #
  # - `index` Substring's strart index.
  # - `length` Length of substring to extract.
  getAttributedBodyTextSubstring: (index, length) ->
    @attributedBodyText.subattributedString(index, length)

  # Public: Returns an {Object} with keys for each attribute at the given
  # character characterIndex, and by reference the range over which the
  # elements apply.
  #
  # - `characterIndex` The character index.
  # - `effectiveRange` (optional) {Object} whose `index` and `length`
  #    properties will be set to effective range of element.
  # - `longestEffectiveRange` (optional) {Object} whose `index` and `length`
  #    properties will be set to longest effective range of element.
  getBodyTextAttributesAtIndex: (characterIndex, effectiveRange, longestEffectiveRange) ->
    @attributedBodyText.getAttributesAtIndex(characterIndex, effectiveRange, longestEffectiveRange)

  # Public: Returns the value for an attribute with a given name of the
  # character at a given characterIndex, and by reference the range over which
  # the attribute applies.
  #
  # - `attribute` Attribute name.
  # - `characterIndex` The character index.
  # - `effectiveRange` (optional) {Object} whose `index` and `length`
  #    properties will be set to effective range of element.
  # - `longestEffectiveRange` (optional) {Object} whose `index` and `length`
  #    properties will be set to longest effective range of element.
  getBodyTextAttributeAtIndex: (attribute, characterIndex, effectiveRange, longestEffectiveRange) ->
    @attributedBodyText.getAttributeAtIndex(attribute, characterIndex, effectiveRange, longestEffectiveRange)

  # Sets the attributes for the characters in the specified range to the
  # specified attributes.
  #
  # - `attributes` {Object} with keys and values for each attribute
  # - `index` Start index character index.
  # - `length` Range length.
  setBodyTextAttributesInRange: (attributes, index, length) ->
    @attributedBodyText.setAttributesInRange(attributes, index, length)
    # Needs mutation event!

  # Public: Adds an element with the given tagName and attributes to the
  # characters in the specified range.
  #
  # - `tagName` Tag name of the element.
  # - `attributes` Element attributes. Use `null` as a placeholder if element
  #    doesn't need attributes.
  # - `index` Start index character index.
  # - `length` Range length.
  addBodyTextAttributeInRange: (attribute, value, index, length) ->
    @attributedBodyText.addAttributeInRange(attribute, value, index, length)
    # Needs mutation event!

  # Public: Adds an element with the given tagName and attributes to the
  # characters in the specified range.
  #
  # - `tagName` Tag name of the element.
  # - `attributes` Element attributes. Use `null` as a placeholder if element
  #    doesn't need attributes.
  # - `index` Start index.
  # - `length` Range length.
  addBodyTextAttributesInRange: (attributes, index, length) ->
    @attributedBodyText.addAttributesInRange(attributes, index, length)
    # Needs mutation event!

  # Public: Removes the element with the tagName from the characters in the
  # specified range.
  #
  # - `tagName` Tag name of the element.
  # - `index` Start index.
  # - `length` Range length.
  removeBodyTextAttributeInRange: (attribute, index, length) ->
    @attributedBodyText.removeAttributeInRange(attribute, index, length)
    # Needs mutation event!

  insertLineBreakInBodyText: (index) ->

  insertImageInBodyText: (index, image) ->

  # Public: Replace body text in the given range.
  #
  # - `insertedText` {String} or {AttributedString}
  # - `index` Start index.
  # - `length` Range length.
  replaceBodyTextInRange: (insertedText, index, length) ->
    if @isRoot
      return

    attributedBodyText = @attributedBodyText
    oldBodyText = attributedBodyText.getString()
    isInOutline = @isInOutline
    outline = @outline
    insertedString

    if insertedText instanceof AttributedString
      insertedString = insertedText.string
    else
      insertedString = insertedText

    assert.ok(insertedString.indexOf('\n') is -1, 'Item body text cannot contain newlines')

    if isInOutline
      replacedText = attributedBodyText.subattributedString(index, length)
      if replacedText.length is 0 and insertedText.length is 0
        return
      mutation = Mutation.createBodyTextMutation this, index, insertedString.length, replacedText
      outline.emitter.emit 'will-change', mutation
      outline.beginChanges()
      outline.recordChange mutation

    attributedBodyText.replaceRangeWithText(index, length, insertedText)
    outline.syncBodyTextToAttributes(this, oldBodyText)

    if isInOutline
      outline.emitter.emit 'did-change', mutation
      outline.endChanges()

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

  # Public: Read-only true if item is part of owning {Outline}
  isInOutline: false
  Object.defineProperty @::, 'isInOutline',
    get: -> @inOutline
    set: (isInOutline) ->
      unless @inOutline is isInOutline
        if isInOutline
          @outline.idsToItems.set(@id, @)
        else
          @outline.idsToItems.delete(@id)

        @inOutline = isInOutline
        each = @firstChild
        while each
          each.isInOutline = isInOutline
          each = each.nextSibling
      @

  # Public: Read-only {Boolean} true if this item has no body text and no
  # attributes and no children.
  isEmpty: null
  Object.defineProperty @::, 'isEmpty',
    get: ->
      not @hasBodyText and
      not @firstChild and
      @attributeNames.length is 0

  # Public: Read-only root {Item}.
  root: null
  Object.defineProperty @::, 'root',
    get: ->
      if @isInOutline
        @outline.root
      else
        each = this
        while each.parent
          each = each.parent
        each

  # Public: Read-only "depth" of {Item} in outline structure. Calculated by
  # summing the {Item:indent} of this item and all of it's ancestors.
  depth: null
  Object.defineProperty @::, 'depth',
    get: ->
      depth = @indent
      ancestor = @parent
      while ancestor
        depth += ancestor.indent
        ancestor = ancestor.parent
      depth

  # Public: Visual indent of {Item} relative to parent. Normally this will be
  # 1 for children with a parent as they are indented one level beyond there
  # parent. But items can be visually over-indented in which case this value
  # would be greater then 1. It can never be less then one for an item that
  # has a parent. It is 0 if an item does not have a parent.
  indent: null
  Object.defineProperty @::, 'indent',
    get: ->
      if indent = @getAttribute('indent')
        parseInt(indent) or 1
      else if @parent
        1
      else
        0

    set: (indent) ->
      indent = 1 if indent < 1

      if previousSibling = @previousSibling
        assert.ok(indent <= previousSibling.indent, 'item indent must be less then or equal to previousSibling indent')

      if nextSibling = @nextSibling
        assert.ok(indent >= nextSibling.indent, 'item indent must be greater then or equal to nextSibling indent')

      if @parent and indent is 1
        indent = null
      else if indent < 1
        indent = null

      @setAttribute('indent', indent)

  row: null
  Object.defineProperty @::, 'row',
    get: ->
      row = 0
      each = @previousItem
      while each
        row++
        each = each.previousItem
      row

  # Public: Read-only parent {Item}.
  parent: null

  # Public: Read-only first child {Item}.
  firstChild: null

  # Public: Read-only last child {Item}.
  lastChild: null

  # Public: Read-only previous sibling {Item}.
  previousSibling: null

  # Public: Read-only next sibling {Item}.
  nextSibling: null

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
    get: -> not not @firstChild

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
    ancestor = item?.parent
    while ancestor
      if ancestor is this
        return true
      ancestor = ancestor.parent
    false

  # Public: Deep clones this item.
  #
  # Returns a duplicate {Item}.
  cloneItem: (deep, remappedIDCallback) ->
    @outline.cloneItem(this, deep, remappedIDCallback)

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
  # inserted at the end. This method sets the indent of child to match
  # referenceSibling or 1.
  #
  # - `child` The inserted child {Item} .
  # - `referenceSibling` (optional) The referenced sibling {Item} .
  insertChildBefore: (child, referenceSibling) ->
    @insertChildrenBefore([child], referenceSibling)

  # Public: Insert the new children before the referenced sibling in this
  # item's list of children. If nextSibling isn't defined the new children are
  # inserted at the end. This method resets the indent of children to match
  # nextSibling or 1.
  #
  # - `children` {Array} of {Item}s to insert.
  # - `nextSibling` (optional) The next sibling {Item} to insert before.
  insertChildrenBefore: (children, nextSibling) ->
    isInOutline = @isInOutline
    outline = @outline

    outline.removeItemsFromParents(children)

    if nextSibling
      previousSibling = nextSibling.previousSibling
    else
      previousSibling = @lastChild

    if isInOutline
      mutation = Mutation.createChildrenMutation this, children, [], previousSibling, nextSibling
      outline.emitter.emit 'will-change', mutation
      outline.beginChanges()
      outline.undoManager.beginUndoGrouping()
      outline.recordChange mutation

    for each, i in children
      assert.ok(each.outline is @outline, 'children must share same outline')
      each.previousSibling = children[i - 1]
      each.nextSibling = children[i + 1]
      each.parent = this

    firstChild = children[0]
    lastChild = children[children.length - 1]

    firstChild.previousSibling = previousSibling
    previousSibling?.nextSibling = firstChild
    lastChild.nextSibling = nextSibling
    nextSibling?.previousSibling = lastChild

    if not firstChild.previousSibling
      @firstChild = firstChild
    if not lastChild.nextSibling
      @lastChild = lastChild

    childIndent = previousSibling?.indent ? nextSibling?.indent ? 1
    for each in children by -1
      each.isInOutline = isInOutline
      each.indent = childIndent

    if isInOutline
      outline.emitter.emit 'did-change', mutation
      outline.undoManager.endUndoGrouping()
      outline.endChanges()

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

    firstChild = children[0]
    lastChild = children[children.length - 1]
    previousSibling = firstChild.previousSibling
    nextSibling = lastChild.nextSibling

    if isInOutline
      mutation = Mutation.createChildrenMutation this, [], children, previousSibling, nextSibling
      outline.emitter.emit 'will-change', mutation
      outline.beginChanges()
      outline.undoManager.beginUndoGrouping()
      outline.recordChange mutation

    previousSibling?.nextSibling = nextSibling
    nextSibling?.previousSibling = previousSibling

    if firstChild is @firstChild
      @firstChild = nextSibling
    if lastChild is @lastChild
      @lastChild = previousSibling

    for each in children
      each.isInOutline = false
      each.nextSibling = null
      each.previousSibling = null
      each.parent = null

    if isInOutline
      outline.emitter.emit 'did-change', mutation
      outline.undoManager.endUndoGrouping()
      outline.endChanges()

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

  ###
  Section: Debug
  ###

  # Extended: Returns debug string for this branch.
  branchToString: (depthString) ->
    depthString ?= ''
    indent = @indent

    while indent
      depthString += '  '
      indent--

    results = [@toString(depthString)]
    for each in @children
      results.push(each.branchToString(depthString))
    results.join('\n')

  # Extended: Returns debug string for this item.
  toString: (depthString) ->
    (depthString or '') + '(' + @id + ') ' + @attributedString.toString()