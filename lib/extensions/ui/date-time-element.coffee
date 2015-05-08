# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

FoldingTextService = require '../../foldingtext-service'
{Disposable, CompositeDisposable} = require 'atom'

class DateTimeElement extends HTMLElement
  constructor: ->
    super()

  createdCallback: ->

  attachedCallback: ->

  detachedCallback: ->

  ###
  Section: Rendering
  ###

  render: ->

  renderMonth: (date) ->

  renderDay: (date) ->


module.exports = document.registerElement 'ft-date-time', prototype: DateTimeElement.prototype