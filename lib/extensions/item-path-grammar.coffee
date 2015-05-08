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

  tokenizeLine: (line, ruleStack, firstLine=false) ->
    tokens = []
    location = 0
    parsed = ItemPath.parse(line)

    if parsed.error
      offset = parsed.error.offset
      location = line.length
      tokens.push @createToken(line.substring(0, offset), ['source.itempath', 'invalid.illegal'])
      tokens.push @createToken(line.substring(offset, line.length), ['source.itempath', 'invalid.illegal.error'])
    else
      for each in parsed.keywords
        if each.offset > location
          tokens.push @createToken(line.substring(location, each.offset), ['source.itempath', 'none'])
        tokens.push @createToken(each.text, ['source.itempath', each.label or 'none'])
        location = each.offset + each.text.length

    if location < line.length
      tokens.push @createToken(line.substring(location, line.length), ['source.itempath', 'none'])

    {} =
      tokens: tokens
      ruleStack: []

