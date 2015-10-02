AttributedString = require '../attributed-string'
Constants = require '../constants'
dom = require '../util/dom'
assert = require 'assert'

beginSerialization = (items, editor, options, context) ->
  context.document = document.implementation.createHTMLDocument()
  context.elementStack = []

  context.topElement = ->
    @elementStack[@elementStack.length - 1]
  context.popElement = ->
    @elementStack.pop()
  context.pushElement = (element) ->
    @elementStack.push(element)

  rootUL = context.document.createElement('ul')
  rootUL.id = Constants.RootID
  context.document.documentElement.lastChild.appendChild(rootUL)
  context.pushElement(rootUL)
  head = context.document.head
  expandedIDs = []

  if editor
    for each in items
      end = each.nextBranch
      while each isnt end
        if editor.isExpanded each
          expandedIDs.push each.id
        each = each.nextItem

  loadedFTMLHead = items[0].outline.loadOptions?.loadedFTMLHead
  if loadedFTMLHead
    for each in loadedFTMLHead.children
      if (each.tagName is 'META' and each.hasAttribute('charset')) or
         (each.tagName is 'META' and each.name is 'expandedItems')
        # Ignore, will write these values ourselves
      else
        head.appendChild(context.document.importNode(each, true))

  if expandedIDs.length
    expandedMeta = context.document.createElement 'meta'
    expandedMeta.name = 'expandedItems'
    expandedMeta.content = expandedIDs.join ' '
    head.appendChild expandedMeta

  encodingMeta = context.document.createElement 'meta'
  encodingMeta.setAttribute 'charset', 'UTF-8'
  head.appendChild encodingMeta

beginSerializeItem = (item, options, context) ->
  parentElement = context.topElement()
  if parentElement.tagName is 'LI'
    context.popElement()
    ulElement = context.document.createElement('ul')
    parentElement.appendChild(ulElement)
    parentElement = ulElement
    context.pushElement(ulElement)

  liElement = context.document.createElement('li')
  liElement.setAttribute 'id', item.id
  for eachName in item.attributeNames
    eachValue = item.getAttribute(eachName)
    liElement.setAttribute eachName, eachValue
  parentElement.appendChild(liElement)

  context.pushElement(liElement)

serializeItemBody = (item, bodyAttributedString, options, context) ->
  liElement = context.topElement()
  pElement = context.document.createElement('p')
  pElement.innerHTML = bodyAttributedString.toInlineFTMLString()
  liElement.appendChild(pElement)

endSerializeItem = (item, options, context) ->
  context.popElement()

endSerialization = (options, context) ->
  require('./tidy-dom')(context.document.documentElement, '\n')
  result = new XMLSerializer().serializeToString(context.document)

cleanFTMLDOM = (element) ->
  each = element
  eachType

  while each
    eachType = each.nodeType
    if eachType is Node.ELEMENT_NODE and each.tagName is 'P'
      each = dom.nodeNextBranch each
    else
      if eachType is Node.TEXT_NODE
        textNode = each
        each = dom.nextNode each
        textNode.parentNode.removeChild textNode
      else
        each = dom.nextNode each

createItem = (outline, liOrRootUL, remapIDCallback) ->
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

  P = liOrRootUL.firstElementChild
  UL = liOrRootUL.lastChild
  text = AttributedString.fromInlineFTML(P)
  item = outline.createItem(text, liOrRootUL.id, remapIDCallback)

  attributes = liOrRootUL.attributes
  for i in [0...attributes.length]
    attr = attributes[i]
    unless attr.name is 'id'
      item.setAttribute(attr.name, attr.value)

  if P isnt UL
    eachLI = UL.firstElementChild
    children = []
    while eachLI
      children.push(createItem(outline, eachLI, remapIDCallback))
      eachLI = eachLI.nextElementSibling
    item.appendChildren(children)
  item

deserializeItems = (ftmlString, outline, options) ->
  parser = new DOMParser()
  htmlDocument = parser.parseFromString(ftmlString, 'text/html')
  rootUL = htmlDocument.getElementById(Constants.RootID)
  unless rootUL
    rootUL = htmlDocument.getElementById('Birch.Root')
    rootUL ?= htmlDocument.getElementById('Birch')
    if rootUL
      rootUL.id = Constants.RootID
  expandedItemIDs = {}
  loadOptions = loadedFTMLHead: htmlDocument.head.cloneNode(true)
  items = []

  items.loadOptions = loadOptions

  if rootUL
    cleanFTMLDOM htmlDocument.body

    metaElements = htmlDocument.head.getElementsByTagName 'meta'
    for each in metaElements
      if each.name is 'expandedItems'
        for eachID in each.content.split ' '
          expandedItemIDs[eachID] = true

    eachLI = rootUL.firstElementChild
    while eachLI
      item = createItem outline, eachLI, (oldID, newID) ->
        if expandedItemIDs[oldID]
          delete expandedItemIDs[oldID]
        expandedItemIDs[newID] = true
      if item
        items.push item
      eachLI = eachLI.nextElementSibling
  else
    throw new Error('Could not find <ul id="Birch"> element.')

  loadOptions.expanded = Object.keys(expandedItemIDs)

  items

module.exports =
  beginSerialization: beginSerialization
  beginSerializeItem: beginSerializeItem
  serializeItemBody: serializeItemBody
  endSerializeItem: endSerializeItem
  endSerialization: endSerialization
  deserializeItems: deserializeItems