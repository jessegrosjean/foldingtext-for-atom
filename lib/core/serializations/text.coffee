tagStartChars = '[A-Z_a-z\\u00C0-\\u00D6\\u00D8-\\u00F6\\u00F8-\\u02FF\\u0370-\\u037D\\u037F-\\u1FFF\\u200C-\\u200D\\u2070-\\u218F\\u2C00-\\u2FEF\\u3001-\\uD7FF\\uF900-\\uFDCF\\uFDF0-\\uFFFD]'
tagWordChars =  '[\\-.0-9\\u00B7\\u0300-\\u036F\\u203F-\\u2040]'
tagWordRegexString = tagStartChars + '(?:' + tagStartChars + '|' + tagWordChars + ')*'
tagRegexTemplate = '(^|\\s+)@(TAGNAME)(?:\\(([^\\)]*)\\))?(?=\\s|$)'
tagRegex = new RegExp(tagRegexTemplate.replace('TAGNAME', tagWordRegexString), 'g')

serializeItemAttributes = (item) ->
  excludedAttributes =
    'data-type': true

  attributes = []
  for name in item.attributeNames
    if (name.indexOf('data-') is 0) and not excludedAttributes[name]
      attribute = '@' + name.substring(5)
      value = item.getAttribute(name)
      if value
        attribute = "#{attribute}(#{value})"
      attributes.push attribute
  if attributes.length
    attributesString = attributes.join(' ')
    if item.bodyText.length
      attributesString = ' ' + attributesString
    attributesString
  else
    ''

serializeItems = (items, editor, serializeItemText) ->
  serializeItemText ?= (item) -> item.bodyText
  text = []
  itemToTXT = (item, indent) ->
    child = item.firstChild
    text.push(indent + serializeItemText(item) + serializeItemAttributes(item))
    indent += '\t'
    while child
      itemToTXT(child, indent)
      child = child.nextSibling
  for each in items
    itemToTXT each, ''
  text.join '\n'

calculateAndExtractAttributes = (text) ->
  attributes = {}
  reservedTags = {}
  newText = text
  removedLength = 0
  tags = []

  while match = tagRegex.exec(text)
    leadingSpace = match[1]
    tag = match[2]
    value = match[3] or ''

    if tags[tag] is undefined and reservedTags[tag] is undefined
      index = match.index - removedLength
      newText = newText.substring(0, index) + newText.substring(index + match[0].length)
      removedLength += match[0].length
      attributes['data-' + tag] = value

  {} =
    text: newText
    attributes: attributes

deserializeItems = (text, outline) ->
  text = text.replace(/(\r\n|\n|\r)/gm,'\n')
  text = text.replace('    ','\t')
  text = text.replace('  ','\t')

  root = outline.createItem()
  root._indentLevel = -1
  lines = text.split '\n'
  stack = [root]

  calculateIndentLevel = (line) ->
    line.match(/^(\t)*/)[0].length

  for line in lines
    {attributes, text} = calculateAndExtractAttributes(line.trim())
    item = outline.createItem(text)

    for name, value of attributes
      item.setAttribute(name, value)

    item._indentLevel = calculateIndentLevel(line)

    parent = stack.pop()
    while parent._indentLevel >= item._indentLevel
      parent = stack.pop()

    parent.appendChild item
    stack.push(parent)
    stack.push(item)

  items = root.children
  for each in items
    each.removeFromParent()
  items.loadOptions = {}
  items

module.exports =
  serializeItems: serializeItems
  deserializeItems: deserializeItems
