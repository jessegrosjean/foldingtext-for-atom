# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

# Focused when in item mode so that cut, copy, and paste will work. But
# causes problems in languages with input managers...
class FocusElement extends HTMLInputElement
  constructor: ->
    super()
    @value = '.'
    @_resetInput =>
      @value = '.'

  createdCallback: ->

  attachedCallback: ->
    @addEventListener('compositionstart', @_resetInput, true)
    @addEventListener('compositionupdate', @_resetInput, true)
    @addEventListener('compositionend', @_resetInput, true)
    @addEventListener('input', @_resetInput, true)

  detachedCallback: ->
    @removeEventListener('compositionstart', @_resetInput, true)
    @removeEventListener('compositionupdate', @_resetInput, true)
    @removeEventListener('compositionend', @_resetInput, true)
    @removeEventListener('input', @_resetInput, true)

module.exports = document.registerElement 'ft-outline-editor-focus',
  extends: 'input'
  prototype: FocusElement.prototype