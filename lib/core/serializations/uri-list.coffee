assert = require 'assert'

beginSerialization = (items, editor, options, context) ->
  context.lines = []

beginSerializeItem = (item, options, context) ->

serializeItemBody = (item, bodyAttributedString, options, context) ->
  context.lines.push("# #{bodyAttributedString.toInlineFTMLString()}")
  context.lines.join('\n')
  context.lines.push item.outline.getFileURL
    selection:
      focusItem: item

endSerializeItem = (item, options, context) ->

endSerialization = (options, context) ->
  context.lines.join('\n')

deserializeItems = (uriList, outline, options) ->
  uris = uriList.split('\n')
  bodyHTMLString = null
  items = []

  for each in uris
    if each[0] is '#'
      bodyHTMLString = each.substring(1).trim()
    else
      bodyHTMLString ?= each
      item = outline.createItem()
      item.bodyHTMLString = bodyHTMLString
      item.addBodyAttributeInRange 'A', { href: each }, 0, item.bodyString.length
      bodyHTMLString = null
      items.push item

  items

module.exports =
  beginSerialization: beginSerialization
  beginSerializeItem: beginSerializeItem
  serializeItemBody: serializeItemBody
  endSerializeItem: endSerializeItem
  endSerialization: endSerialization
  deserializeItems: deserializeItems