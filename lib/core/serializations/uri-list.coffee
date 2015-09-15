assert = require 'assert'

serializeItems = (items, editor, options) ->
  lines = []
  for each in items
    lines.push "# #{each.bodyHTMLString}"
    lines.push each.outline.getFileURL
      selection:
        focusItem: each
  lines.join('\n')

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
  serializeItems: serializeItems
  deserializeItems: deserializeItems