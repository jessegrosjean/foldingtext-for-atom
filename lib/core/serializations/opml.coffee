assert = require 'assert'

serializeItems = (items, editor) ->
  opmlDocumentument = document.implementation.createDocument(null, 'opml', null)
  loadedOPMLHead = items[0].outline.loadOptions?.loadedOPMLHead
  headElement = opmlDocumentument.createElement('head')
  bodyElement = opmlDocumentument.createElement('body')
  documentElement = opmlDocumentument.documentElement

  documentElement.setAttribute('version', '2.0')
  documentElement.appendChild(headElement)

  if loadedOPMLHead
    for each in loadedOPMLHead.children
      if each.tagName.toLowerCase() is 'expansionstate'
        # Ignore, will write these values ourselves
      else
        headElement.appendChild(opmlDocumentument.importNode(each, true))

  if editor
    lastVisibleLineNumber = 0
    expandedLines = []
    calculateExpandedLines = (item, end) ->
      if not item or item is end
        return lastVisibleLineNumber
      else
        lastVisibleLineNumber++
      if editor.isExpanded item
        expandedLines.push(lastVisibleLineNumber)
        lastVisibleLineNumber = calculateExpandedLines(item.firstChild, end)
      calculateExpandedLines(item.nextSibling, end)

    for each in items
      lastVisibleLineNumber = calculateExpandedLines(each, each.nextBranch)
    expansionStateElement = opmlDocumentument.createElement('expansionState')
    expansionStateElement.textContent = expandedLines.join(',')
    headElement.appendChild(expansionStateElement)

  itemToOPML = (item) ->
    outlineElement = opmlDocumentument.createElementNS(null, 'outline')
    outlineElement.setAttribute 'id', item.id
    outlineElement.setAttribute 'text', item.bodyHTML
    for eachName in item.attributeNames
      unless eachName is 'id' or eachName is 'text'
        opmlName = eachName
        if opmlName.indexOf('data-') is 0
          opmlName = opmlName.substr(5)
          opmlValue = item.getAttribute(eachName)
          if opmlName is 'created' or opmlName is 'modified'
            opmlValue = item.getAttribute(eachName, false, Date).toGMTString()

        outlineElement.setAttribute opmlName, opmlValue

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

deserializeItems = (opml, outline) ->
  opmlDocument = (new DOMParser()).parseFromString(opml, 'text/xml')
  documentElement = opmlDocument.documentElement
  headElement = documentElement.getElementsByTagName('head')[0]
  bodyElement = documentElement.getElementsByTagName('body')[0]
  expandedItemIDs = {}
  expandedLines = []
  ownerName = ''
  title = ''

  if headElement
    titleElement = headElement.getElementsByTagName('title')[0]
    title = titleElement?.textContent.trim() or ''

    ownerNameElement = headElement.getElementsByTagName('ownerName')[0]
    ownerName = ownerNameElement?.textContent.trim() or ''

    expansionState = headElement.getElementsByTagName('expansionState')[0]
    if expansionState
      expandedLines = (parseInt(each) for each in expansionState.textContent.trim().split(','))

  lastVisibleLineNumber = 0
  expandItemIfNeeded = (item) ->
    unless item
      return lastVisibleLineNumber
    else
      lastVisibleLineNumber++
    if lastVisibleLineNumber is expandedLines[0]
      expandedLines.shift()
      expandedItemIDs[item.id] = true
      lastVisibleLineNumber = expandItemIfNeeded(item.firstChild)
    expandItemIfNeeded(item.nextSibling)

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
          if name is 'created' or name is 'modified'
            value = new Date(value)
          item.setAttribute 'data-' + name, value

    eachOutline = outlineElement.firstElementChild
    while eachOutline
      item.appendChild(outlineElementToItem(eachOutline, outline))
      eachOutline = eachOutline.nextElementSibling

    item

  items = []
  eachOutline = bodyElement.firstElementChild
  while eachOutline
    item = outlineElementToItem(eachOutline, outline)
    eachOutline = eachOutline.nextElementSibling
    expandItemIfNeeded(item)
    items.push item

  items.loadOptions =
    title: title
    ownerName: ownerName
    loadedOPMLHead: headElement.cloneNode(true)
    expanded: Object.keys(expandedItemIDs)
  items

module.exports =
  serializeItems: serializeItems
  deserializeItems: deserializeItems
