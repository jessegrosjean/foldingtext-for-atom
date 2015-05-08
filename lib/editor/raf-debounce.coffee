# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

module.exports = (func, wait, immediate) ->
  ->
    args = arguments
    context = this
    timeout = null

    later = ->
      timeout = null
      if not immediate
        func.apply(context, args)

    callNow = immediate and not timeout

    if wait is undefined
      cancelAnimationFrame(timeout)
      timeout = requestAnimationFrame(later)
    else
      clearTimeout(timeout)
      timeout = setTimeout(later, wait)

    if callNow
      func.apply(context, args)