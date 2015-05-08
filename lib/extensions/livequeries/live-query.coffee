# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

rafdebounce = require '../../editor/raf-debounce'
{Emitter, CompositeDisposable} = require 'atom'

# Private: A live query.
module.exports =
class OutlineLiveQuery

  debouncedRun: null

  constructor: (@xpathExpression) ->
    @emitter = new Emitter()
    @debouncedRun = rafdebounce(@run.bind(this), 300)

  ###
  Section: Events
  ###

  # Public: Invoke the given callback when the value of {::results} changes.
  #
  # - `callback` {Function} to be called when the path changes.
  #   - `results` {Array} of matches.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChange: (callback) ->
    @emitter.on 'did-change', callback

  # Public: Invoke the given callback when the query is destroyed.
  #
  # - `callback` {Function} to be called when the query is destroyed.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  ###
  Section: Configuring Queries
  ###

  # Public: Read-only xpath expression.
  xpathExpression: null

  # Public: Read-only xpath expression syntax error.
  xpathExpressionError: null

  # Public: Set new xpath expression and schedule an update if the query is
  # started.
  setXPathExpression: (@xpathExpression) ->
    @scheduleRun()

  ###
  Section: Running Queries
  ###

  # Public: Read-only is query started.
  started: false

  startQuery: ->
    return if @started
    @started = true

  stopQuery: ->
    return unless @started
    @started = false

  scheduleRun: ->
    if @started
      @debouncedRun()

  run: ->

  ###
  Section: Getting Query Results
  ###

  # Public: Read-only {Array} of matching {Items}.
  results: []