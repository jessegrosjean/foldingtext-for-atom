# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

parents = (node) ->
  nodes = [node]
  while node = node.parent
    nodes.unshift(node)
  nodes

shortestPath = (node1, node2) ->
  if node1 is node2
    [node1]
  else
    parents1 = parents(node1)
    parents2 = parents(node2)
    commonDepth = 0
    while parents1[commonDepth] is parents2[commonDepth]
      commonDepth++
    parents1.splice(0, commonDepth - 1)
    parents2.splice(0, commonDepth)
    parents1.concat(parents2)

commonAncestor = (node1, node2) ->
  if node1 is node2
    [node1]
  else
    parents1 = parents(node1)
    parents2 = parents(node2)
    while parents1[depth] is parents2[depth]
      depth++
    parents1[depth - 1]

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

stopEventPropagation = (commandListeners) ->
  newCommandListeners = {}
  for commandName, commandListener of commandListeners
    do (commandListener) ->
      newCommandListeners[commandName] = (event) ->
        event.stopPropagation()
        commandListener.call(this, event)
  newCommandListeners

module.exports =
  parents: parents
  shortestPath: shortestPath
  commonAncestor: commonAncestor
  previousNode: previousNode
  nextNode: nextNode
  nodeNextBranch: nodeNextBranch
  lastDescendantNodeOrSelf: lastDescendantNodeOrSelf
  childIndexOfNode: childIndexOfNode
  stopEventPropagation: stopEventPropagation