# Copyright (c) 2015 Jesse Grosjean. All rights reserved.
Constants = require './constants'
urls = require './util/urls'
path = require 'path'

serializations = []
registerSerialization = (serialization) ->
  serialization.priority ?= Number.Infinity
  serializations.push serialization
  serializations.sort (a, b) ->
    a.priority - b.priority

getSerializationsForMimeType = (mimeType) ->
  (each for each in serializations when mimeType in each.mimeTypes)

getMimeTypeForURI = (uri) ->
  uri ?= ''
  extension = path.extname(uri).toLowerCase().substr(1)
  for each in serializations
    if extension in each.extensions
      return each.mimeTypes[0]

###
Section: Items
###

serializeItems = (items, editor, mimeType, options) ->
  mimeType ?= Constants.FTMLMimeType
  getSerializationsForMimeType(mimeType)[0].serializeItems(items, editor, options)

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
  serializeItems: (items, editor) ->
    require('./serializations/ftml').serializeItems(items, editor)
  deserializeItems: (itemsData, outline) ->
    require('./serializations/ftml').deserializeItems(itemsData, outline)

registerSerialization
  priority: 1
  extensions: ['opml']
  mimeTypes: [Constants.OPMLMimeType]
  serializeItems: (items, editor) ->
    require('./serializations/opml').serializeItems(items, editor)
  deserializeItems: (itemsData, outline) ->
    require('./serializations/opml').deserializeItems(itemsData, outline)

registerSerialization
  priority: 2
  extensions: []
  mimeTypes: [Constants.HTMLMimeType]
  serializeItems: (items, editor) ->
    require('./serializations/html-fragment').serializeItems(items, editor)
  deserializeItems: (itemsData, outline) ->
    require('./serializations/html-fragment').deserializeItems(itemsData, outline)

registerSerialization
  priority: 3
  extensions: []
  mimeTypes: [Constants.URIListMimeType]
  serializeItems: (items, editor) ->
    require('./serializations/uri-list').serializeItems(items, editor)
  deserializeItems: (itemsData, outline) ->
    require('./serializations/uri-list').deserializeItems(itemsData, outline)

registerSerialization
  priority: 4
  extensions: []
  mimeTypes: [Constants.TEXTMimeType]
  serializeItems: (items, editor) ->
    require('./serializations/text').serializeItems(items, editor)
  deserializeItems: (itemsData, outline) ->
    require('./serializations/text').deserializeItems(itemsData, outline)

module.exports =
  registerSerialization: registerSerialization
  getMimeTypeForURI: getMimeTypeForURI
  serializeItems: serializeItems
  deserializeItems: deserializeItems
  writeItemsToDataTransfer: writeItemsToDataTransfer
  readItemsFromDataTransfer: readItemsFromDataTransfer