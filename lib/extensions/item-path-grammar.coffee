# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

ItemPath = require '../core/item-path'
# construct path on separate line for endokken
grammarPath = atom.config.resourcePath + '/node_modules/first-mate/lib/grammar'
Grammar = require grammarPath

module.exports=
class ItemPathGrammar extends Grammar
  constructor: (registry) ->
    super registry,
      name: 'ItemPath'
      scopeName: "source.itempath"

  getScore: -> 0

  tokenizeLine: (line, ruleStack, firstLine=false, compatibilityMode=true) ->
    tags = [@startIdForScope('source.itempath')]
    parsed = ItemPath.parse(line)
    ruleStack = []
    location = 0

    if parsed.error
      offset = parsed.error.offset
      location = line.length
      tags.push(@startIdForScope('invalid.illegal'))
      tags.push(offset)
      tags.push(@startIdForScope('invalid.illegal.error'))
      tags.push(line.length - offset)
    else
      for each in parsed.keywords
        if each.offset > location
          tags.push(@startIdForScope('none'))
          tags.push(each.offset - location)
        tags.push(@startIdForScope(each.label or 'none'))
        tags.push(each.text.length)
        location = each.offset + each.text.length

    if location < line.length
      tags.push(@startIdForScope('none'))
      tags.push(line.length - location)

    # {line, tags, ruleStack}