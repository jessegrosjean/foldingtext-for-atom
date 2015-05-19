assert = require 'assert'

serializeItems = (items, editor) ->
  opmlDocumentument = document.implementation.createDocument(null, 'opml', null)
  headElement = opmlDocumentument.createElement('head')
  bodyElement = opmlDocumentument.createElement('body')
  documentElement = opmlDocumentument.documentElement

  documentElement.setAttribute('version', '2.0')
  documentElement.appendChild(headElement)

  itemToOPML = (item) ->
    outlineElement = opmlDocumentument.createElementNS(null, 'outline')
    outlineElement.setAttribute 'id', item.id
    outlineElement.setAttribute 'text', item.bodyHTML
    for eachName in item.attributeNames
      unless eachName is 'id' or eachName is 'text'
        opmlName = eachName
        if opmlName.indexOf('data-') is 0
          opmlName = opmlName.substr(5)
        outlineElement.setAttribute opmlName, item.getAttribute(eachName)

    if current = item.firstChild
      while current
        childOutline = itemToOPML current
        outlineElement.appendChild childOutline
        current = current.nextSibling
    outlineElement

  for each in items
    bodyElement.appendChild itemToOPML(each)
  documentElement.appendChild bodyElement

  require('./tidy-dom')(opmlDocumentument.documentElement, '\n')
  new XMLSerializer().serializeToString documentElement

outlineElementToItem = (outlineElement, outline) ->
  assert.ok(outlineElement.tagName.toUpperCase() is 'OUTLINE', "Expected OUTLINE element but got #{outlineElement.tagName}")
  attributes = outlineElement.attributes
  item = outline.createItem '', outlineElement.getAttribute('id')
  item.bodyHTML = outlineElement.getAttribute('text') or ''

  for attr in attributes
    if attr.specified
      name = attr.name
      value = attr.value
      unless name is 'id' or name is 'text'
        item.setAttribute 'data-' + name, value

  eachOutline = outlineElement.firstElementChild
  while eachOutline
    item.appendChild(outlineElementToItem(eachOutline, outline))
    eachOutline = eachOutline.nextElementSibling

  item

deserializeItems = (opml, outline) ->
  opmlDocument = (new DOMParser()).parseFromString(opml, 'text/xml')
  documentElement = opmlDocument.documentElement
  headElement = documentElement.getElementsByTagName('head')[0]
  bodyElement = documentElement.getElementsByTagName('body')[0]
  eachOutline = bodyElement.firstElementChild
  items = []
  items.metaState = {}
  while eachOutline
    items.push outlineElementToItem(eachOutline, outline)
    eachOutline = eachOutline.nextElementSibling
  items

module.exports =
  serializeItems: serializeItems
  deserializeItems: deserializeItems
