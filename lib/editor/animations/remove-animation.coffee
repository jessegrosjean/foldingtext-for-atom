# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

Velocity = require 'velocity-animate'

module.exports =
class RemoveAnimation

  @id = 'RemoveAnimation'

  constructor: (id, item, itemRenderer) ->
    @itemRenderer = itemRenderer
    @_id = id
    @_item = item
    @_removingLI = null
    @_targetHeight = 0

  fastForward: ->
    @_removingLI?.style.height = @_targetHeight + 'px'

  complete: ->
    @itemRenderer.completedAnimation @_id
    if @_removingLI
      Velocity @_removingLI, 'stop', true
      @_removingLI.parentElement.removeChild @_removingLI

  remove: (LI, context) ->
    startHeight = LI.clientHeight
    targetHeight = 0

    if @_removingLI
      Velocity @_removingLI, 'stop', true
      @_removingLI.parentElement.removeChild @_removingLI

    @_removingLI = LI
    @_targetHeight = targetHeight
    Velocity LI, 'stop', true

    Velocity
      e: LI
      p:
        tween: [targetHeight, startHeight]
        height: targetHeight
      o:
        easing: context.easing
        duration: context.duration
        begin: (elements) ->
          LI.style.overflowY = 'hidden'
          LI.style.height = startHeight
          LI.style.visibility = 'hidden'
          LI.style.pointerEvents = 'none'
        progress: (elements, percentComplete, timeRemaining, timeStart, tweenLIHeight) ->
          if tweenLIHeight < 0
            LI.style.height = '0px'
            LI.style.marginBottom = tweenLIHeight + 'px'
          else
            LI.style.marginBottom = null
        complete: (elements) =>
          @complete()