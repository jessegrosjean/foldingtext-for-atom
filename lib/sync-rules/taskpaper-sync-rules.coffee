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

tagRange = (item, tag) ->
  if match = item.bodyText.match(regexForTag(tag))
    return {} =
      location: match.index
      length: match[0].length

removeTag = (item, tag) ->
  if range = tagRange(item, tag)
    item.replaceBodyTextInRange('', range.location, range.length)

addTag = (item, tag, value) ->
  tagString = '@' + tag
  if value
    tagString += "(#{value})"

  range = tagRange(item, tag)
  unless range
    range =
      location: item.bodyText.length
      length: 0

  if range.location > 0
    tagString = ' ' + tagString

  item.replaceBodyTextInRange(tagString, range.location, range.length)

parseTags = (text) ->
  tags = {}
  if text.indexOf('@') isnt -1
    while match = tagRegex.exec(text)
      leadingSpace = match[1]
      tag = match[2]
      value = match[3] ? ''
      if not tags[tag] and not reservedTags[tag]
        tags[tag] = value
  tags

syncAttributeToBodyText = (item, attribute) ->
  if attribute is 'type'
  else
    value = item.getAttribute(attribute)
    if value isnt null
      addTag(item, attribute, value)
    else
      removeTag(item, attribute)

syncBodyTextToAttributes = (item, oldBodyText) ->
  oldTags = parseTags(oldBodyText)
  newTags = parseTags(item.bodyText)

  for tag of oldTags
    unless newTags[tag]
      item.removeAttribute(tag)

  for tag of newTags
    if newTags[tag] isnt oldTags[tag]
      item.setAttribute(tag, newTags[tag])

module.exports =
  syncAttributeToBodyText: syncAttributeToBodyText
  syncBodyTextToAttributes: syncBodyTextToAttributes