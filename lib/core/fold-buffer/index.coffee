SpanBuffer = require '../span-buffer'
FoldSpan = require './fold-span'

class FoldBuffer extends SpanBuffer

  constructor: (children) ->
    super(children)

  createSpan: (text) ->
    new FoldSpan(text)

  foldRange: (location, length) ->


module.exports = FoldBuffer