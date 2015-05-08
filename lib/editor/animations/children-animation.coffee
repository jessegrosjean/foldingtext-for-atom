# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

Velocity = require 'velocity-animate'
assert = require 'assert'

module.exports =
class ChildrenAnimation

  @id = 'Children'

  constructor: (id, item, itemRenderer) ->
    @itemRenderer = itemRenderer
    @_id = id
    @_expandingUL = null
    @_collapsingUL = null
    @_item = item
    @_targetHeight = 0

  fastForward: (context) ->
    if @_expandingUL
      @_expandingUL.style.height = @_targetHeight + 'px'
    else if @_collapsingUL
      @_collapsingUL.style.height = @_targetHeight + 'px'

  expand: (UL, context) ->
    startHeight = if @_collapsingUL then @_collapsingUL.clientHeight else 0
    targetHeight = UL.clientHeight
    itemRenderer = @itemRenderer
    id = @_id

    if @_collapsingUL
      Velocity @_collapsingUL, 'stop', true
      @_collapsingUL.parentElement.removeChild @_collapsingUL
      @_collapsingUL = null

    @_expandingUL = UL
    @_targetHeight = targetHeight

    Velocity
      e: UL
      p:
        height: targetHeight
      o:
        easing: context.easing
        duration: context.duration
        begin: (elements) ->
          UL.style.height = startHeight + 'px'
          UL.style.overflowY = 'hidden'
        complete: (elements) ->
          UL.style.height = null
          UL.style.marginBottom = null
          UL.style.overflowY = null
          itemRenderer.completedAnimation id

  collapse: (UL, context) ->
    startHeight = UL.clientHeight
    targetHeight = 0

    if @_expandingUL
      Velocity @_expandingUL, 'stop', true
      @_expandingUL = null

    @_collapsingUL = UL
    @_targetHeight = targetHeight

    LI = UL.parentElement.parentElement

    Velocity
      e: UL
      p:
        tween: [targetHeight, startHeight],
        height: targetHeight
      o:
        easing: context.easing
        duration: context.duration
        begin: (elements) ->
          UL.style.overflowY = 'hidden'
          UL.style.pointerEvents = 'none'
          UL.style.height = startHeight + 'px'
        progress: (elements, percentComplete, timeRemaining, timeStart, tweenULHeight) ->
          if tweenULHeight < 0
            UL.style.height = '0px'
            LI.style.marginBottom = tweenULHeight + 'px'
          else
            LI.style.marginBottom = null
        complete: (elements) =>
          UL.parentElement?.removeChild UL
          @itemRenderer.completedAnimation(@_id)