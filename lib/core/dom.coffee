# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

previousNode = (node) ->
  previousSibling = node.previousSibling
  if previousSibling
    lastDescendantNodeOrSelf(previousSibling)
  else
    node.parentNode or null

nextNode = (node) ->
  firstChild = node.firstChild
  if firstChild
    firstChild
  else
    nextSibling = node.nextSibling
    if nextSibling
      nextSibling
    else
      parent = node.parentNode
      while parent
        nextSibling = parent.nextSibling
        if nextSibling
          return nextSibling
        parent = parent.parentNode
      null

nodeNextBranch = (node) ->
  if node.nextSibling
    node.nextSibling
  else
    p = node.parentNode
    while p
      if p.nextSibling
        return p.nextSibling
      p = p.parentNode
    null

lastDescendantNodeOrSelf = (node) ->
  lastChild = node.lastChild
  each = node
  while lastChild
    each = lastChild
    lastChild = each.lastChild
  each

childIndexOfNode = (node) ->
  index = 0
  while (node = node.previousSibling) isnt null
    index++
  index

module.exports =
  previousNode: previousNode
  nextNode: nextNode
  nodeNextBranch: nodeNextBranch
  lastDescendantNodeOrSelf: lastDescendantNodeOrSelf
  childIndexOfNode: childIndexOfNode