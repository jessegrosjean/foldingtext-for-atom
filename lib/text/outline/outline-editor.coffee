OutlineBuffer = require './outline-buffer'
Outline = require '../../core/outline'
shortid = require '../../core/shortid'

class OutlineEditor

  constructor: (outline, nativeTextBuffer) ->
    @id = shortid()
    @outline = outline or Outline.buildOutlineSync()
    @nativeTextBuffer = nativeTextBuffer
    @ignoreNativeTextBufferChanges = 0
    @outlineBuffer = new OutlineBuffer(outline)
    @ignoreOutlineBufferChanges = 0

    @outlineBuffer.onDidChange (e) ->
      if not ignoreOutlineBufferChanges
        ignoreNativeTextBufferChanges++
        nativeTextBuffer.setTextInRange(e.oldRange, e.newText)
        ignoreNativeTextBufferChanges--

    nativeTextBuffer.onDidChange (e) ->
      if not ignoreNativeTextBufferChanges
        ignoreOutlineBufferChanges++
        outlineBuffer.setTextInRange(e.newText, e.oldRange)
        ignoreOutlineBufferChanges--



  ###
  Section: Hoisting
  ###

  getHoistedItem: ->
    @outlineBuffer.getHoistedItem()

  setHoistedRow: (row) ->
    @setHoistedItem @outlineBuffer.lineForRow(row).item

  setHoistedItem: (item) ->
    # clear buffer
    # populate buffer from new item
    @outlineBuffer.setHoistedItem()

  ###
  Section: Filtering
  ###

  ###
  Section: Expand & Collapse
  ###

module.exports = OutlineEditor