# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

{Disposable, CompositeDisposable} = require 'atom'

class ScrollElement extends HTMLElement
  createdCallback: ->
    atom.commands.add this,
      'core:move-up': => @scrollUp()
      'core:move-down': => @scrollDown()
      'core:page-up': => @pageUp()
      'core:page-down': => @pageDown()
      'core:move-to-top': => @scrollToTop()
      'core:move-to-bottom': => @scrollToBottom()

  attachedCallback: ->

  detachedCallback: ->

  attributeChangedCallback: (attrName, oldVal, newVal) ->

  scrollUp: ->

  scrollDown: ->

  pageUp: ->

  pageDown: ->

  scrollToTop: ->

  scrollToBottom: ->

module.exports = document.registerElement 'ft-scroll', prototype: ScrollElement.prototype