# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

Velocity = require 'velocity-animate'

module.exports =
class MoveAnimation

  @id = 'MoveAnimation'

  constructor: (id, item, itemRenderer) ->
    @_id = id
    @_item = item
    @itemRenderer = itemRenderer
    @_movingLIClone = null

  fastForward: ->

  beginMove: (LI, position) ->
    movingLIClone = @_movingLIClone

    unless movingLIClone
      movingLIClone = LI.cloneNode true
      movingLIClone.style.marginTop = 0
      movingLIClone.style.position = 'absolute'
      movingLIClone.style.top = position.top + 'px'
      movingLIClone.style.left = position.left + 'px'
      movingLIClone.style.width = position.width + 'px'
      movingLIClone.style.pointerEvents = 'none'

      # Add simulated selection if in text edit mode.
      itemRenderer = @itemRenderer
      selectionRange = itemRenderer.editor.selection

      if selectionRange.isTextMode and selectionRange.focusItem is @_item
        itemRect = LI.getBoundingClientRect()
        selectionRects = []

        # focusClientRect is more acurate in a number of collapsed cases,
        # so use it when possible. Otherwise just use
        # document.getSelection() rects.
        if selectionRange.isCollapsed
          selectionRects.push selectionRange.focusClientRect
        else
          domSelection = itemRenderer.editor.DOMGetSelection()
          if domSelection.rangeCount > 0
            selectionRects = domSelection.getRangeAt(0).getClientRects()

        for rect in selectionRects
          selectDIV = document.createElement('div')
          selectDIV.style.position = 'absolute'
          selectDIV.style.top = (rect.top - itemRect.top) + 'px'
          selectDIV.style.left = (rect.left - itemRect.left) + 'px'
          selectDIV.style.width = rect.width + 'px'
          selectDIV.style.height = rect.height + 'px'
          selectDIV.style.zIndex = '-1'

          if rect.width <= 1
            selectDIV.className = 'ft-simulated-selection-cursor'
            selectDIV.style.width = '1px'
          else
            selectDIV.className = 'ft-simulated-selection'

          movingLIClone.appendChild selectDIV

      @itemRenderer.editorElement.itemAnimationLayerElement.appendChild movingLIClone
      @_movingLIClone = movingLIClone

  performMove: (LI, position, context) ->
    movingLIClone = @_movingLIClone

    Velocity movingLIClone, 'stop', true

    Velocity
      e: movingLIClone
      p:
        top: position.top
        left: position.left
        width: position.width
      o:
        easing: context.easing
        duration: context.duration
        begin: (elements) ->
          LI.style.opacity = '0'
        complete: (elements) =>
          LI.style.opacity = null
          movingLIClone.parentElement.removeChild movingLIClone
          @itemRenderer.completedAnimation @_id