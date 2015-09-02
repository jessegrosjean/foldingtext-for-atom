class SpanLeaf

  constructor: (@children) ->
    @parent = null
    length = 0
    for each in @children
      each.parent = this
      length += each.getLength()
    @length = length

  clone: ->
    children = []
    for each in @children
      children.push(each.clone())
    new @constructor(children)

  ###
  Section: Characters
  ###

  getLength: ->
    @length

  getOffset: (child) ->
    length = @parent?.getOffset(this) or 0
    if child
      for each in @children
        if each is child
          break
        length += each.getLength()
    length

  ###
  Section: Spans
  ###

  getSpanCount: ->
    @children.length

  getSpan: (index) ->
    @children[index]

  getSpanIndex: (child) ->
    index = @parent?.getSpanIndex(this) or 0
    if child
      index += @children.indexOf(child)
    index

  getSpanAtOffset: (offset, index=0) ->
    for each in @children
      childLength = each.getLength()
      if offset > childLength
        offset -= childLength
        index++
      else
        return {} =
          span: each
          index: index
          offset: offset

  iterateSpans: (start, count, operation) ->
    for i in [start...start + count]
      if operation(@children[i]) is false
        return false

  insertSpans: (index, spans) ->
    for each in spans
      each.parent = this
      @length += each.getLength()
    @children = @children.slice(0, index).concat(spans).concat(@children.slice(index))

  removeSpans: (start, deleteCount) ->
    end = start + deleteCount
    for i in [start...end]
      each = @children[i]
      each.parent = null
      @length -= each.getLength()
    @children.splice(start, deleteCount)

  ###
  Section: Util
  ###

  collapse: (spans) ->
    @children.push.apply(spans, @children)

module.exports = SpanLeaf