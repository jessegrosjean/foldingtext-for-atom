SpliceArrayChunkSize = 100000

module.exports =
  spliceArray: (originalArray, start, length, insertedArray=[]) ->
    if insertedArray.length < SpliceArrayChunkSize
      originalArray.splice(start, length, insertedArray...)
    else
      removedValues = originalArray.splice(start, length)
      for chunkStart in [0..insertedArray.length] by SpliceArrayChunkSize
        chunkEnd = chunkStart + SpliceArrayChunkSize
        chunk = insertedArray.slice(chunkStart, chunkEnd)
        originalArray.splice(start + chunkStart, 0, chunk...)
      removedValues

  leadingTabs: (tabs) ->
    tabCount = 0
    while text[tabCount] is '\t'
      tabCount++
    tabCount

  replace: (string, start, end, substitute) ->
    string.substring(0, start) + substitute + string.substring(end)

  repeat: (pattern, count) ->
    if count is 0
      ''
    else
      result = ''
      while count > 1
        if count & 1
          result += pattern
        count >>= 1
        pattern += pattern
      result + pattern

  parents: (node) ->
    nodes = [node]
    while node = node.parent
      nodes.unshift(node)
    nodes

  shortestPath: (node1, node2) ->
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

  commonAncestor: (node1, node2) ->
    if node1 is node2
      [node1]
    else
      parents1 = parents(node1)
      parents2 = parents(node2)
      while parents1[depth] is parents2[depth]
        depth++
      parents1[depth - 1]

  newlineRegex: /\r\n|\n|\r/g