{ tagRegex, regexForTag, tagRange, encodeTag, reservedTags, parseTags } = require '../core/serializations/text'
taskRegex = /([\-+*])\s/
projectRegex = /:$/

removeTag = (item, tag) ->
  if range = tagRange(item.bodyString, tag)
    item.replaceBodyRange(range.location, range.length, '')

addTag = (item, tag, value) ->
  tagString = encodeTag(tag, value)
  range = tagRange(item.bodyString, tag)
  unless range
    range =
      location: item.bodyString.length
      length: 0
  if range.location > 0
    tagString = ' ' + tagString
  item.replaceBodyRange(range.location, range.length, tagString)

parseType = (text, item) ->
  if text.match(taskRegex)
    'task'
  else if text.match(projectRegex)
    'project'
  else
    'note'

syncAttributeToBody = (item, attribute, value, oldValue) ->
  if not reservedTags[attribute]
    if attribute is 'data-type'
      # Remove old value syntax
      switch oldValue
        when 'project'
          item.replaceBodyRange(item.bodyString.length - 1, 1, '')
        when 'task'
          item.replaceBodyRange(item.bodyString.match(/\s*/)[0].length, 2, '')

      # Add new value syntax
      switch value
        when 'project'
          item.replaceBodyRange(item.bodyString.length, 0, ':')
        when 'task'
          item.replaceBodyRange(item.bodyString.match(/\s*/)[0].length, 0, '- ')

    else if attribute.indexOf('data-') is 0
      if value isnt null
        addTag(item, attribute.substr(5), value)
      else
        removeTag(item, attribute.substr(5))

syncBodyToAttributes = (item, oldBody) ->
  item.setAttribute('data-type', parseType(item.bodyString, item))

  oldTags = parseTags(oldBody)
  newTags = parseTags item.bodyString, (tag, value, match) ->
    leadingSpace = match[1]
    start = match.index + leadingSpace.length
    length = match[0].length - leadingSpace.length
    item.addBodyHighlightInRange('tag', '', start, length)
    item.addBodyHighlightInRange('tagname', '', start + 1, match[2].length)
    if value
      item.addBodyHighlightInRange('tagvalue', '', start + 1 + match[2].length + 1, value.length)

  for tag of oldTags
    unless newTags[tag]?
      item.removeAttribute(tag)

  for tag of newTags
    if newTags[tag] isnt oldTags[tag]
      item.setAttribute(tag, newTags[tag])

module.exports =
  syncAttributeToBody: syncAttributeToBody
  syncBodyToAttributes: syncBodyToAttributes