Constants = require '../Constants'
dom = require '../dom'

serializeItems = (items, editor) ->
  htmlDocument = document.implementation.createHTMLDocument()
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

  if expandedIDs.length
    expandedMeta = htmlDocument.createElement 'meta'
    expandedMeta.name = 'expandedItems'
    expandedMeta.content = expandedIDs.join ' '
    head.appendChild expandedMeta

  encodingMeta = htmlDocument.createElement 'meta'
  encodingMeta.setAttribute 'charset', 'UTF-8'
  head.appendChild encodingMeta

  style.type = 'text/css'
  style.appendChild htmlDocument.createTextNode('p { white-space: pre-wrap; }')
  head.appendChild style

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
  metaState = {}
  items = []

  items.metaState = metaState

  if rootUL
    cleanFTMLDOM htmlDocument.body

    metaElements = htmlDocument.head.getElementsByTagName 'meta'
    for each in metaElements
      if each.name is 'expandedItems'
        for eachID in each.content.split ' '
          expandedItemIDs[eachID] = true

    eachLI = rootUL.firstElementChild
    while eachLI
      item = outline.createItem null, outline.outlineStore.importNode(eachLI, true), (oldID, newID) ->
        if expandedItemIDs[oldID]
          delete expandedItemIDs[oldID]
          expandedItemIDs[newID] = true

      if item
        items.push item

      eachLI = eachLI.nextElementSibling
  else
    throw new Error('Could not find <ul id="FoldingText"> element.')

  metaState['expandedItemIDs'] = Object.keys(expandedItemIDs)

  items

module.exports =
  serializeItems: serializeItems
  deserializeItems: deserializeItems
