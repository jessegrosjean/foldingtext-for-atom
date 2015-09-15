AttributedString = require '../attributed-string'
Constants = require '../constants'
dom = require '../util/dom'
assert = require 'assert'

serializeItems = (items, editor, options) ->
  htmlDocument = document.implementation.createHTMLDocument()
  loadedFTMLHead = items[0].outline.loadOptions?.loadedFTMLHead
  rootUL = htmlDocument.createElement('ul')
  style = document.createElement('style')
  head = htmlDocument.head
  expandedIDs = []

  if editor
    for each in items
      end = each.nextBranch
      while each isnt end
        if editor.isExpanded each
          expandedIDs.push each.id
        each = each.nextItem

  if loadedFTMLHead
    for each in loadedFTMLHead.children
      if (each.tagName is 'META' and each.hasAttribute('charset')) or
         (each.tagName is 'META' and each.name is 'expandedItems')
        # Ignore, will write these values ourselves
      else
        head.appendChild(htmlDocument.importNode(each, true))

  if expandedIDs.length
    expandedMeta = htmlDocument.createElement 'meta'
    expandedMeta.name = 'expandedItems'
    expandedMeta.content = expandedIDs.join ' '
    head.appendChild expandedMeta

  encodingMeta = htmlDocument.createElement 'meta'
  encodingMeta.setAttribute 'charset', 'UTF-8'
  head.appendChild encodingMeta

  rootUL.id = Constants.RootID
  htmlDocument.documentElement.lastChild.appendChild rootUL

  itemToFTML = (item) ->
    liElement = htmlDocument.createElement('li')
    liElement.setAttribute 'id', item.id
    for eachName in item.attributeNames
      liElement.setAttribute eachName, item.getAttribute(eachName)

    pElement = htmlDocument.createElement('p')
    pElement.innerHTML = item.bodyHTMLString
    liElement.appendChild(pElement)

    if current = item.firstChild
      ulElement = htmlDocument.createElement('ul')
      liElement.appendChild(ulElement)
      while current
        childLi = itemToFTML current
        ulElement.appendChild childLi
        current = current.nextSibling
    liElement

  for each in items
    rootUL.appendChild itemToFTML(each)

  require('./tidy-dom')(htmlDocument.documentElement, '\n')
  new XMLSerializer().serializeToString(htmlDocument)

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
    throw new Error('Could not find <ul id="FoldingText"> element.')

  loadOptions.expanded = Object.keys(expandedItemIDs)

  items

module.exports =
  serializeItems: serializeItems
  deserializeItems: deserializeItems
