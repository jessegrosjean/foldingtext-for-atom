# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

Item = require './item'

module.exports =
class ItemRange

  constructor: (@startItem, @startOffset, @endItem, @endOffset) ->

  getItemsInRange: ->
    items = []
    @forEachItemInRange (item, location, length, fullySelected) ->
      items.push(item)
    items

  forEachItemInRange: (callback) ->
    if @startItem is @endItem
      callback(@startItem, @startOffset, @endOffset - @startOffset, false)
    else
      each = @startItem.nextItem
      callback(@startItem, @startOffset, each.bodyString.length - @startOffset, false)
      while each isnt @endItem
        callback(each, 0, each.bodyString.length, true)
        each = each.nextItem
      if @endOffset > 0
        callback(@endItem, 0, @endOffset, false)

  rangeByExtendingToItem: (editor) ->
    endItem = @endItem
    endOffset = endItem.bodyString.length

    if not @isCollapsed and @endOffset is 0
      endOffset = 0
    else
      nextItem = editor?.getNextVisibleItem(endNode)
      nextItem ?= endNode.nextItem
      if nextItem
        endItem = nextItem
        endOffset = 0
    new ItemRange(@startItem, 0, endItem, endOffset)

  rangeByExtendingToBranch: ->
    commonAncestors = Item.getCommonAncestors(@getItemsInRange())
    last = commonAncestors[commonAncestors.length - 1].lastDescendantOrSelf
    next = last.nextItem
    if next
      new ItemRange(commonAncestors[0], 0, next, 0)
    else
      new ItemRange(commonAncestors[0], 0, last, last.bodyString.length)
