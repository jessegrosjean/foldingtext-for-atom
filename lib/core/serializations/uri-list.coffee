assert = require 'assert'

serializeItems = (items, editor) ->
  lines = []
  for each in items
    lines.push "# #{each.bodyHTML}"
    lines.push each.outline.getFileURL
      selection:
        focusItem: each
  lines.join('\n')

deserializeItems = (uriList, outline) ->
  uris = uriList.split('\n')
  bodyHTML = null
  items = []

  for each in uris
    if each[0] is '#'
      bodyHTML = each.substring(1).trim()
    else
      bodyHTML ?= each
      item = outline.createItem()
      item.bodyHTML = bodyHTML
      item.addBodyTextAttributeInRange 'A', { href: each }, 0, item.bodyText.length
      bodyHTML = null
      items.push item

  items

module.exports =
  serializeItems: serializeItems
  deserializeItems: deserializeItems