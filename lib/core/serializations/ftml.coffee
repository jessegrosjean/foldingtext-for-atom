Constants = require '../constants'
dom = require '../dom'

serializeItems = (items, editor) ->
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

  for each in items
    rootUL.appendChild each._liOrRootUL.cloneNode(true)

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

createItem = (outline, LI, remapIDCallback) ->
  P = LI.firstElementChild
  UL = LI.lastChild
  text = P.textContent
  item = outline.createItem(text, LI.id, remapIDCallback)

  if LI.hasAttributes()
    attributes = LI.attributes
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

deserializeItems = (ftmlString, outline) ->
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
