# Copyright (c) 2015 Jesse Grosjean. All rights reserved.
Constants = require './constants'
urls = require './util/urls'
path = require 'path'

serializations = []
defaultSerialization = null

registerSerialization = (serialization, makeDefault) ->
  if makeDefault
    defaultSerialization = serialization
  serialization.priority ?= Number.Infinity
  serializations.push serialization
  serializations.sort (a, b) ->
    a.priority - b.priority

getSerializationsForMimeType = (mimeType) ->
  results = (each.serialization for each in serializations when mimeType in each.mimeTypes)
  if results.length is 0 and defaultSerialization?
    results.push(defaultSerialization.serialization)
  results

getMimeTypeForURI = (uri) ->
  uri ?= ''
  extension = path.extname(uri).toLowerCase().substr(1)
  for each in serializations
    if extension in each.extensions
      return each.mimeTypes[0]

###
Section: Items
###

serializeItems = (items, editor, mimeType, options={}) ->
  mimeType ?= Constants.FTMLMimeType
  serialization = getSerializationsForMimeType(mimeType)[0]

  firstItem = items[0]
  lastItem = items[items.length - 1]
  startOffset = options.startOffset ? 0
  endOffset = options.endOffset ? lastItem.bodyString.length
  options.baseDepth ?= Number.MAX_VALUE
  context = {}

  for each in items
    if each.depth < options.baseDepth
      options.baseDepth = each.depth

  serialization.beginSerialization(items, editor, options, context)

  if items.length is 1
    serialization.beginSerializeItem(items[0], options, context)
    serialization.serializeItemBody(items[0], items[0].bodySubattributedString(startOffset, endOffset - startOffset), options, context)
    serialization.endSerializeItem(items[0], options, context)
  else
    itemStack = []
    for each in items
      while itemStack[itemStack.length - 1]?.depth >= each.depth
        serialization.endSerializeItem(itemStack.pop(), options, context)

      itemStack.push(each)
      serialization.beginSerializeItem(each, options, context)
      itemBody = each.bodyAttributedString

      if each is firstItem
        itemBody = itemBody.subattributedString(startOffset, itemBody.length - startOffset)
      else if each is lastItem
        itemBody = itemBody.subattributedString(0, endOffset)
      serialization.serializeItemBody(each, itemBody, options, context)

    while itemStack.length
      serialization.endSerializeItem(itemStack.pop(), options, context)

  serialization.endSerialization(options, context)

deserializeItems = (itemsData, outline, mimeType, options) ->
  mimeType ?= Constants.FTMLMimeType
  getSerializationsForMimeType(mimeType)[0].deserializeItems(itemsData, outline, options)

writeItemsToDataTransfer = (items, editor, dataTransfer, mimeType, options) ->
  if mimeType
    dataTransfer.setData mimeType, serializeItems(items, editor, mimeType, options)
  else
    for each in serializations
      dataTransfer.setData each.mimeTypes[0], serializeItems(items, editor, each.mimeTypes[0])

readItemsFromDataTransfer = (editor, dataTransfer, mimeType, options) ->
  for each in serializations
    if (mimeType in each.mimeTypes) or not mimeType
      itemsData = dataTransfer.getData each.mimeTypes[0]
      if itemsData
        try
          if items = deserializeItems(itemsData, editor.outline, each.mimeTypes[0], options)
            return items if items.length
        catch error
          console.log "#{each} failed reading mimeType #{mimeType}. Now trying with other serializations."

  # Create items with links to pasteboard file items.
  items = []
  for eachItem in dataTransfer.items
    file = eachItem.getAsFile()
    if file?.path and file?.path.length > 0
      item = editor.outline.createItem file.name
      fileURL = urls.getFileURLFromPathnameAndOptions(file.path)
      fileHREF = urls.getHREFFromFileurls(editor.outline.getFileURL(), fileURL)
      item.addBodyAttributeInRange 'A', href: fileHREF, 0, file.name.length
      items.push item
  items

registerSerialization
  priority: 0
  extensions: ['ftml']
  mimeTypes: [Constants.FTMLMimeType]
  serialization: require('./serializations/ftml')

registerSerialization
  priority: 1
  extensions: ['opml']
  mimeTypes: [Constants.OPMLMimeType]
  serialization: require('./serializations/opml')

registerSerialization
  priority: 2
  extensions: []
  mimeTypes: [Constants.HTMLMimeType]
  serialization: require('./serializations/html-fragment')

registerSerialization
  priority: 3
  extensions: []
  mimeTypes: [Constants.URIListMimeType]
  serialization: require('./serializations/uri-list')

registerSerialization
  priority: 4
  extensions: []
  mimeTypes: [Constants.TEXTMimeType]
  serialization: require('./serializations/text')

module.exports =
  registerSerialization: registerSerialization
  getMimeTypeForURI: getMimeTypeForURI
  serializeItems: serializeItems
  deserializeItems: deserializeItems
  writeItemsToDataTransfer: writeItemsToDataTransfer
  readItemsFromDataTransfer: readItemsFromDataTransfer