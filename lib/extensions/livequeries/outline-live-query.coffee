# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

{CompositeDisposable} = require 'atom'
LiveQuery = require './live-query'

# A live query over an {Outline}.
module.exports =
class OutlineLiveQuery extends LiveQuery

  # Public: Read-only the {Outline} being queried.
  outline: null
  querySubscriptions: null
  outlineDestroyedSubscription: null

  constructor: (@outline, xpathExpression) ->
    super xpathExpression

    @outlineDestroyedSubscription = @outline.onDidDestroy =>
      @stopQuery()
      @outlineDestroyedSubscription.dispose()
      @emitter.emit 'did-destroy'

  ###
  Section: Running Queries
  ###

  startQuery: ->
    return if @started

    @started = true
    @querySubscriptions = new CompositeDisposable
    @querySubscriptions.add @outline.onDidChange (e) =>
      @scheduleRun()
    @querySubscriptions.add @outline.onDidChangePath (path) =>
      @scheduleRun()
    @run()

  stopQuery: ->
    return unless @started

    @started = false
    @querySubscriptions.dispose()
    @querySubscriptions = null

  run: ->
    return unless @started
    try
      @xpathExpressionError = null
      @results = @outline.getItemsForXPath(
        @xpathExpression,
        @namespaceResolver
      )
    catch error
      @xpathExpressionError = error
      @results = null

    @emitter.emit 'did-change', @results