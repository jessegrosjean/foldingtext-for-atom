assert = require 'assert'

beginSerialization = (items, editor, options, context) ->
  context.document = document.implementation.createDocument(null, 'opml', null)
  context.elementStack = []

  context.topElement = ->
    @elementStack[@elementStack.length - 1]
  context.popElement = ->
    @elementStack.pop()
  context.pushElement = (element) ->
    @elementStack.push(element)

  headElement = context.document.createElement('head')
  bodyElement = context.document.createElement('body')
  documentElement = context.document.documentElement

  documentElement.setAttribute('version', '2.0')
  documentElement.appendChild(headElement)
  documentElement.appendChild(bodyElement)
  context.pushElement(bodyElement)

  loadedOPMLHead = items[0].outline.loadOptions?.loadedOPMLHead
  if loadedOPMLHead
    for each in loadedOPMLHead.children
      if each.tagName.toLowerCase() is 'expansionstate'
        # Ignore, will write these values ourselves
      else
        headElement.appendChild(context.document.importNode(each, true))

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
    expansionStateElement = context.document.createElement('expansionState')
    expansionStateElement.textContent = expandedLines.join(',')
    headElement.appendChild(expansionStateElement)

beginSerializeItem = (item, options, context) ->
  parentElement = context.topElement()
  outlineElement = context.document.createElementNS(null, 'outline')
  outlineElement.setAttribute 'id', item.id
  for eachName in item.attributeNames
    unless eachName is 'id' or eachName is 'text'
      opmlName = eachName
      if opmlName.indexOf('data-') is 0
        opmlName = opmlName.substr(5)
        opmlValue = item.getAttribute(eachName)
        if opmlName is 'created' or opmlName is 'modified'
          opmlValue = item.getAttribute(eachName, false, Date).toGMTString()
      outlineElement.setAttribute opmlName, opmlValue
  parentElement.appendChild(outlineElement)
  context.pushElement(outlineElement)

serializeItemBody = (item, bodyAttributedString, options, context) ->
  outlineElement = context.topElement()
  outlineElement.setAttribute 'text', bodyAttributedString.toInlineFTMLString()

endSerializeItem = (item, options, context) ->
  context.popElement()

endSerialization = (options, context) ->
  require('./tidy-dom')(context.document.documentElement, '\n')
  result = new XMLSerializer().serializeToString(context.document)

deserializeItems = (opml, outline, options) ->
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
    item = outline.createItem '', outlineElement.getAttribute('id')
    item.bodyHTMLString = outlineElement.getAttribute('text') or ''

    if outlineElement.hasAttributes()
      attributes = outlineElement.attributes
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
  beginSerialization: beginSerialization
  beginSerializeItem: beginSerializeItem
  serializeItemBody: serializeItemBody
  endSerializeItem: endSerializeItem
  endSerialization: endSerialization
  deserializeItems: deserializeItems