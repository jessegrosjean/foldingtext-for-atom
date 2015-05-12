# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

ItemBodyEncoder = require './item-body-encoder'
Constants = require './constants'
dom = require './dom'

itemsToTXT = (items, editor) ->
  itemToTXT = (item, indent) ->
    itemText = []
    child = item.firstChild
    itemText.push(indent + item.bodyText)
    indent += '\t'
    while child
      itemText.push itemToTXT(child, indent)
      child = child.nextSibling
    itemText.join '\n'

  text = []
  for each in items
    text.push itemsToTXT each
  text.join '\n'

itemsFromTXT = (text, editor) ->
  lines = text.split '\n'
  outline = editor.outline
  items = []
  if lines.length is 1
    items.itemFragmentString = lines[0].trim()
  else
    for each in lines
      items.push outline.createItem(eachLine.trim())
  items

cleanHTMLDOM = (element) ->
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

tidyHTMLDOM = (element, indent) ->
  if element.tagName is 'P'
    return

  eachChild = element.firstElementChild
  if eachChild
    childIndent = indent + '  '
    while eachChild
      tagName = eachChild.tagName
      if tagName is 'UL' and not eachChild.firstElementChild
        ref = eachChild
        eachChild = eachChild.nextElementSibling
        element.removeChild ref
      else
        tidyHTMLDOM eachChild, childIndent
        element.insertBefore element.ownerDocument.createTextNode(childIndent), eachChild
        eachChild = eachChild.nextElementSibling
    element.appendChild element.ownerDocument.createTextNode(indent)

itemsToHTML = (items, editor) ->
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

  tidyHTMLDOM htmlDocument.documentElement, '\n'

  serializer = new XMLSerializer()
  serializer.serializeToString(htmlDocument)

itemsFromHTML = (htmlString, outline, editor) ->
  parser = new DOMParser()
  htmlDocument = parser.parseFromString(htmlString, 'text/html')
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
    cleanHTMLDOM htmlDocument.body

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
    body = htmlDocument.body
    firstChild = body.firstElementChild

    if firstChild and firstChild.tagName is 'UL'
      # special handling
    else
      items.itemFragmentString = ItemBodyEncoder.elementToAttributedString body

  metaState['expandedItemIDs'] = Object.keys(expandedItemIDs)

  ###
  if (editor) {
    items.forEach(function (each) {
      var end = each.nextBranch;
      while (each !== end) {
        if (expandedItemIDs[each.id]) {
          editor.editorState(each).expanded = true;
        }
        each = each.nextItem;
      }
    });
  }
  ###

  items

itemsToOPML = (items, editor) ->
  opmlDoc = document.implementation.createDocument(null, 'opml', null)
  headElement = opmlDoc.createElement('head')
  bodyElement = opmlDoc.createElement('body')
  documentElement = opmlDoc.documentElement

  documentElement.setAttribute('version', '2.0')
  documentElement.appendChild(headElement)

  itemToOPML = (item) ->
    outlineElement = opmlDoc.createElementNS(null, 'outline')
    for eachName in item.attributeNames
      outlineElement.setAttribute eachKey, item.attribute(eachName)

    outlineElement.setAttribute 'id', item.id
    outlineElement.setAttribute 'text', item.bodyHTML

    if item.hasChildren
      current = item.firstChild
      while current
        childOutline = itemToOPML current
        outlineElement.appendChild childOutline
        current = current.nextSibling

    outlineElement

  for each in items
    bodyElement.appendChild itemToOPML(each)

  documentElement.appendChild bodyElement

  new XMLSerializer().serializeToString documentElement

OPMLToItems = (opml, editor) ->
  outlineElementToNode = (outlineElement) ->
    attributes = outlineElement.attributes
    eachOutline = outlineElement.firstElementChild
    node = tree.createNode '', outlineElement.getAttribute('id')
    for attr in attributes
      if attr.specified
        name = attr.name
        value = attr.value
        if name is 'text'
          node.setAttributedTextContentFromHTML value
        else if name is 'id'
          # ignore
        else
          node.setAttribute name, value
    while eachOutline
      node.appendChild outlineElementToNode(eachOutline)
      eachOutline = eachOutline.nextElementSibling
    node

  try
    opmlDoc = (new DOMParser()).parseFromString(opml, 'text/xml')
    tree = this
    state

    unless opmlDoc
      return null

    documentElement = opmlDoc.documentElement
    unless documentElement
      return null

    headElement = documentElement.getElementsByTagName('head')[0]
    if headElement
      state = headElement.getAttribute('jsonstate')

    bodyElement = documentElement.getElementsByTagName('body')[0]
    unless bodyElement
      return null

    eachOutline = bodyElement.firstElementChild
    nodes = []

    while eachOutline
      nodes.push outlineElementToNode(eachOutline)
      eachOutline = eachOutline.nextElementSibling

    return {} =
      nodes: nodes
      state: state
  catch error
    console.log error

  null

writeItems = (items, editor, dataTransfer) ->
  dataTransfer.setData 'text/plain', itemsToHTML(items, editor)
  dataTransfer.setData 'text/html', itemsToHTML(items, editor)
  #dataTransfer.setData 'text/xml+opml', itemsToOPML(items, editor)

readItems = (editor, dataTransfer) ->
  htmlString = dataTransfer.getData 'text/html'
  items = null

  if htmlString
    items = itemsFromHTML htmlString, editor.outline, editor

  unless items
    txtString = dataTransfer.getData 'text/plain'
    if txtString
      items = itemsFromHTML txtString, editor.outline, editor

  unless items
    items = []
    for eachItem in dataTransfer.items
      file = eachItem.getAsFile()
      path = file.path
      if path and path.length > 0
        item = editor.outline.createItem file.name
        item.addElementInBodyTextRange 'A', { href: 'file://' + file.path }, 0, file.name.length
        items.push item

  return items or []

module.exports =
  itemsToHTML: itemsToHTML
  itemsFromHTML: itemsFromHTML
  writeItems: writeItems
  readItems: readItems