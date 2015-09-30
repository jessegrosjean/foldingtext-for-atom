assert = require 'assert'

# This only suports fragments of inline html on a single line. Otherwise it
# throws so that the "text" serializer has a chance to process the outline.

beginSerialization = (items, editor, options, context) ->
  assert.ok(items.length is 1, 'Inline-HTML serializer can only serialize a single item.')

beginSerializeItem = (item, options, context) ->

serializeItemBody = (item, bodyAttributedString, options, context) ->
  context.result = bodyAttributedString.toInlineFTMLString()

endSerializeItem = (item, options, context) ->

endSerialization = (options, context) ->
  context.result

deserializeItems = (html, outline, options) ->
  html = html.replace(/(\r\n|\n|\r)/gm,'\n')
  assert.ok(html.split('\n').length is 1, 'Inline-HTML deseriaizer can only deserialize a single line.')
  div = document.createElement 'div'
  div.innerHTML = html
  assert.ok(div.firstElementChild, 'Inline-HTML deseriaizer must deserialize at least one element.')
  item = outline.createItem()
  item.bodyHTMLString = html
  [item]

module.exports =
  beginSerialization: beginSerialization
  beginSerializeItem: beginSerializeItem
  serializeItemBody: serializeItemBody
  endSerializeItem: endSerializeItem
  endSerialization: endSerialization
  deserializeItems: deserializeItems