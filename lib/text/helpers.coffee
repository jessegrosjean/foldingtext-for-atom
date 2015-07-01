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

  newlineRegex: /\r\n|\n|\r/g