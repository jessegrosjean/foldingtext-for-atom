# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

GlobalMouseDown = 0
GlobalMouseButton = {}

isGlobalMouseDown = ->
  GlobalMouseDown > 0

isGlobalLeftMouseDown = ->
  GlobalMouseButton[0]

isGlobalWheelMouseDown = ->
  GlobalMouseButton[1]

isGlobalRightMouseDown = ->
  GlobalMouseButton[2]

handleGlobalMouseDown = (e) ->
  GlobalMouseDown++
  GlobalMouseButton[e.button] = true

handleGlobalMouseUp = (e) ->
  GlobalMouseDown--
  GlobalMouseButton[e.button] = false

document.addEventListener 'mousedown', handleGlobalMouseDown, true
document.addEventListener 'mouseup', handleGlobalMouseUp, true

module.exports =
  isGlobalMouseDown: isGlobalMouseDown
  isGlobalLeftMouseDown: isGlobalLeftMouseDown
  isGlobalWheelMouseDown: isGlobalWheelMouseDown
  isGlobalRightMouseDown: isGlobalRightMouseDown