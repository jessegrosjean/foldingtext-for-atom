SpanLeaf = require './span-leaf'

class SpanBranch

  constructor: (@children) ->
    @parent = null
    spanCount = 0
    length = 0
    for each in @children
      each.parent = this
      spanCount += each.getSpanCount()
      length += each.getLength()
    @spanCount = spanCount
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

  getLocation: (child) ->
    length = @parent?.getLocation(this) or 0
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
    @spanCount

  getSpan: (index) ->
    for each in @children
      childSpanCount = each.getSpanCount()
      if index >= childSpanCount
        index -= childSpanCount
      else
        return each.getSpan(index)

  getSpanIndex: (child) ->
    index = @parent?.getSpanIndex(this) or 0
    if child
      for each in @children
        if each is child
          break
        index += each.getSpanCount()
    index

  getSpanInfoAtLocation: (location, spanIndex=0, spanLocation=0) ->
    for each in @children
      childLength = each.getLength()
      if location > childLength
        location -= childLength
        spanIndex += each.getSpanCount()
        spanLocation += childLength
      else
        return each.getSpanInfoAtLocation(location, spanIndex, spanLocation)

  getSpans: (start, count) ->
    start ?= 0
    count ?= @getSpanCount() - start

    spans = []
    @iterateSpans start, count, (span) ->
      spans.push(span)
    spans

  iterateSpans: (spanIndex, count, operation) ->
    for child in @children
      childSpanCount = child.getSpanCount()
      if spanIndex < childSpanCount
        used = Math.min(count, childSpanCount - spanIndex)
        if child.iterateSpans(spanIndex, used, operation) is false
          return false
        if (count -= used) is 0
          break
        spanIndex = 0
      else
        spanIndex -= childSpanCount

  insertSpans: (spanIndex, spans) ->
    @spanCount += spans.length

    for each in spans
      @length += each.getLength()

    for child, i in @children
      childSpanCount = child.getSpanCount()
      if spanIndex <= childSpanCount
        child.insertSpans(spanIndex, spans)
        if child instanceof SpanLeaf and child.children.length > 50
          while child.children.length > 50
            spilled = child.children.splice(child.children.length - 25, 25)
            newleaf = new SpanLeaf(spilled)
            child.length -= newleaf.length
            @children.splice(i + 1, 0, newleaf)
            newleaf.parent = this
          @maybeSpill()
        break
      spanIndex -= childSpanCount

  removeSpans: (spanIndex, deleteCount) ->
    @spanCount -= deleteCount
    i = 0
    while child = @children[i]
      childSpanCount = child.getSpanCount()
      if spanIndex < childSpanCount
        childDeleteCount = Math.min(deleteCount, childSpanCount - spanIndex)
        childOldCharactersCount = child.getLength()
        child.removeSpans(spanIndex, childDeleteCount)
        @length -= (childOldCharactersCount - child.getLength())
        if childSpanCount is childDeleteCount
          @children.splice(i--, 1)
          child.parent = null
        if (deleteCount -= childDeleteCount) is 0
          break
        spanIndex = 0
      else
        spanIndex -= childSpanCount
      i++
    @maybeCollapse(deleteCount)

  mergeSpans: (spanIndex, count) ->
    prev = null
    removeStart = spanIndex
    removeRanges = []
    removeRange = null
    @iterateSpans spanIndex, count, (each) ->
      if prev?.mergeWithSpan(each)
        unless removeRange
          removeRange = spanIndex: removeStart count: 0
          removeRanges.push(removeRange)
        removeRange.count++
      else
        removeRange = null
        removeStart++
    for each in removeRanges
      @removeSpans(each.spanIndex, each.count)

  ###
  Section: Tree Balance
  ###

  maybeSpill: ->
    if @children.length <= 10
      return

    current = this
    while current.children.length > 10
      spilled = current.children.splice(current.children.length - 5, 5)
      sibling = new SpanBranch(spilled)
      if current.parent
        current.spanCount -= sibling.spanCount
        current.length -= sibling.length
        index = current.parent.children.indexOf(current)
        current.parent.children.splice(index + 1, 0, sibling)
      else
        copy = new SpanBranch(current.children)
        copy.parent = current
        current.children = [copy, sibling]
        current = copy
      sibling.parent = current.parent
    current.parent.maybeSpill()

  maybeCollapse: (deleteCount) ->
    if (@spanCount - deleteCount) > 25
      return

    if @children.length > 1 or not (@children[0] instanceof SpanLeaf)
      spans = []
      @collapse(spans)
      @children = [new SpanLeaf(spans)]
      @children[0].parent = this

  collapse: (spans) ->
    for each in @children
      each.collapse(spans)

module.exports = SpanBranch