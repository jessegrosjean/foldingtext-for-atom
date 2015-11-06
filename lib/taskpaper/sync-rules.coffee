{ tagRegex, regexForTag, tagRange, encodeTag, reservedTags, parseTags } = require '../core/serializations/text'
smartLinks = require './smart-links'
taskRegex = /^([\-+*])\s/
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
    startBodyString = item.bodyString
    if attribute is 'data-type'
      # Remove old value syntax
      switch oldValue
        when 'project'
          item.replaceBodyRange(item.bodyString.length - 1, 1, '')
        when 'task'
          item.replaceBodyRange(0, 2, '')

      # Add new value syntax
      switch value
        when 'project'
          item.replaceBodyRange(item.bodyString.length, 0, ':')
        when 'task'
          item.replaceBodyRange(0, 0, '- ')

    else if attribute.indexOf('data-') is 0
      if value?
        addTag(item, attribute.substr(5), value)
      else
        removeTag(item, attribute.substr(5))

    if startBodyString isnt item.bodyString
      highlightItemBody(item)

syncBodyToAttributes = (item, oldBody) ->
  type = parseType(item.bodyString, item)
  item.setAttribute('data-type', type)

  if type is 'task'
    item.addBodyHighlightAttributeInRange('link', 'toggledone', 0, 1)

  oldTags = parseTags(oldBody)
  newTagMatches = []
  newTags = parseTags item.bodyString, (tag, value, match) ->
    newTagMatches.push
      tag: tag
      value: value
      match: match

  highlightItemBody(item, type, newTagMatches)

  for tag of oldTags
    unless newTags[tag]?
      item.removeAttribute(tag)

  for tag of newTags
    if newTags[tag] isnt oldTags[tag]
      item.setAttribute(tag, newTags[tag])

emailRegex = /\b[A-Z0-9\._%+\-]+@[A-Z0-9\.\-]+\.[A-Z]{2,4}\b/gi
webRegex = /\b(?:([a-z][\w\-]+:(?:\/{1,3}|[a-z0-9%])|www\d{0,3}[.])(?:[^\s()<>]+|\([^\s()<>]+\))+(?:\([^\s()<>]+\)|[^`!()\[\]{};:'".,<>?«»“”‘’\s]))/gi

highlightItemBody = (item, type, tagMatches) ->
  bodyString = item.bodyString

  type ?= parseType(bodyString, item)
  if type is 'task'
    item.addBodyHighlightAttributeInRange('buttonlink', 'button://toggledone', 0, 1)

  smartLinks.highlightLinks(item)

  unless tagMatches
    tagMatches = []
    parseTags bodyString, (tag, value, match) ->
      tagMatches.push
        tag: tag
        value: value
        match: match

  for each in tagMatches
    tag = each.tag
    value = each.value
    match = each.match
    leadingSpace = match[1]
    start = match.index + leadingSpace.length
    length = match[0].length - leadingSpace.length
    item.addBodyHighlightAttributeInRange('tag', '', start, length)
    localTagName = tag.substr(5)
    attributes = tagname: tag, filterlink: "filter://@#{localTagName}"
    item.addBodyHighlightAttributesInRange(attributes, start, match[2].length + 1)

    if value?.length
      attributes = tagvalue: value, filterlink: "filter://@#{localTagName} = #{value}"
      item.addBodyHighlightAttributesInRange(attributes, start + 1 + match[2].length + 1, value.length)

module.exports =
  syncAttributeToBody: syncAttributeToBody
  syncBodyToAttributes: syncBodyToAttributes
