Span = require '../span-buffer/span'

class FoldSpan extends Span

  @folded: false

  constructor: (text) ->
    super(text)

  clone: ->
    clone = super()
    clone.folded = @folded
    clone

  setIsFolded: (isFolded) ->
    if @folded isnt isFolded
      @folded = isFolded

module.exports = FoldSpan