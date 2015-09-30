{ repeat } = require '../util'
Item = require '../item'

tagStartChars = '[A-Z_a-z\\u00C0-\\u00D6\\u00D8-\\u00F6\\u00F8-\\u02FF\\u0370-\\u037D\\u037F-\\u1FFF\\u200C-\\u200D\\u2070-\\u218F\\u2C00-\\u2FEF\\u3001-\\uD7FF\\uF900-\\uFDCF\\uFDF0-\\uFFFD]'
tagWordChars =  '[\\-.0-9\\u00B7\\u0300-\\u036F\\u203F-\\u2040]'
tagWordRegexString = "#{tagStartChars}(?:#{tagStartChars}|#{tagWordChars})*"
tagRegexString = "(^|\\s+)@(#{tagWordRegexString})(?:\\(([^\\)]*)\\))?(?=\\s|$)"
tagRegex = new RegExp(tagRegexString, 'g')

reservedTags =
  id: true
  line: true
  indent: true

regexForTag = (tag) ->
  new RegExp("(^|\\s)@(#{tag})(\\([^\\)]*\\))?")

tagRange = (text, tag) ->
  if match = text.match(regexForTag(tag))
    return {} =
      location: match.index
      length: match[0].length

encodeTag = (tag, value) ->
  if value
    "@#{tag}(#{value})"
  else
    "@#{tag}"

parseTags = (text, callback) ->
  tags = {}
  if text.indexOf('@') isnt -1
    while match = tagRegex.exec(text)
      leadingSpace = match[1]
      tag = 'data-' + match[2]
      value = match[3] ? ''
      if not tags[tag]? and not reservedTags[tag]
        tags[tag] = value
        if callback
          callback(tag, value, match)
  tags

# Serialize

beginSerialization = (items, editor, options, context) ->
  context.lines = []

beginSerializeItem = (item, options, context) ->

serializeItemBody = (item, bodyAttributedString, options, context) ->
  bodyString = bodyAttributedString.string
  if options.includeAttributes
    encodedAttributes = []
    for name in item.attributeNames
      if (name.indexOf('data-') is 0)
        encodedAttributes.push(encodeTag(name.substr(5), item.getAttribute(name)))
    if encodedAttributes.length
      encodedAttributes = encodedAttributes.join(' ')
      if bodyString.length
        encodedAttributes = ' ' + encodedAttributes
      bodyString += encodedAttributes
  context.lines.push(repeat('\t', item.depth - 1) + bodyString)

endSerializeItem = (item, options, context) ->

endSerialization = (options, context) ->
  context.lines.join('\n')

# Deserialize

deserializeItemBody = (item) ->

deserializeItem = (text, outline, extractAttributes) ->
  item = outline.createItem()
  indent = text.match(/^(\t)*/)[0].length + 1
  body = text.substring(indent - 1)
  item.indent = indent

  if extractAttributes
    removedLength = 0
    parseTags body, (tag, value, match) ->
      item.setAttribute(tag, value)
      index = match.index - removedLength
      body = body.substring(0, index) + body.substring(index + match[0].length)
      removedLength += match[0].length

  item.bodyString = body
  item

deserializeItems = (text, outline, options={}) ->
  extractAttributes = options.extractAttributes ? true

  text = text.replace(/(\r\n|\n|\r)/gm,'\n')
  text = text.replace('    ','\t')
  text = text.replace('  ','\t')
  lines = text.split '\n'

  flatItems = []
  for each in lines
    flatItems.push(deserializeItem(each, outline, extractAttributes))

  roots = Item.buildItemHiearchy(flatItems)
  roots.loadOptions = {}
  roots

module.exports =
  tagRegex: tagRegex
  reservedTags: reservedTags
  regexForTag: regexForTag
  tagRange: tagRange
  encodeTag: encodeTag
  parseTags: parseTags
  beginSerialization: beginSerialization
  beginSerializeItem: beginSerializeItem
  serializeItemBody: serializeItemBody
  endSerializeItem: endSerializeItem
  endSerialization: endSerialization
  deserializeItems: deserializeItems
