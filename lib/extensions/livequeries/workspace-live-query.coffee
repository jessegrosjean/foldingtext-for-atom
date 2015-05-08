# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

OutlineLiveQuery = require './outline-live-query'
{CompositeDisposable} = require 'atom'
LiveQuery = require './live-query'

# A live query over all {Outline}s in a {Workspace}.
module.exports =
class WorkspaceLiveQuery extends LiveQuery

  outlineIDsToQueryInfo: null
  workspaceSubscription: null

  constructor: (xpathExpression) ->
    super xpathExpression

  ###
  Section: Configuring Queries
  ###

  # Public: Set new xpath expression and schedule an update if the query is
  # started.
  setXPathExpression: (xpathExpression) ->
    super xpathExpression

    for id, queryInfo of @outlineIDsToQueryInfo
      queryInfo.query.setXPathExpression @xpathExpression

  ###
  Section: Running Queries
  ###

  startQuery: ->
    return if @started
    super

    @outlineIDsToQueryInfo = {}
    @workspaceSubscription = atom.workspace.observeOutlineEditors (editor) =>
      @startObservingOutline editor.outline

  startObservingOutline: (outline) ->
    unless @outlineIDsToQueryInfo[outline.id]
      query = new OutlineLiveQuery outline, @xpathExpression
      querySubscriptions = new CompositeDisposable

      @outlineIDsToQueryInfo[outline.id] =
        query: query
        querySubscriptions: querySubscriptions

      querySubscriptions.add query.onDidChange =>
        @scheduleRun()

      querySubscriptions.add query.onDidDestroy =>
        @stopObservingOutline outline

      query.startQuery()

  stopObservingOutline: (outline) ->
    queryInfo = @outlineIDsToQueryInfo[outline.id]
    delete @outlineIDsToQueryInfo[outline.id]
    queryInfo.query.stopQuery()
    queryInfo.querySubscriptions.dispose()
    @scheduleRun()

  stopQuery: ->
    return unless @started
    super

    @workspaceSubscription.dispose()
    @workspaceSubscription = null

    for id, queryInfo of @outlineIDsToQueryInfo
      @stopObservingOutline queryInfo.query.outline

  run: ->
    return unless @started

    @results = []
    @xpathExpressionError = null

    for id, queryInfo of @outlineIDsToQueryInfo
      query = queryInfo.query
      if query.results is null
        @results = null
        @xpathExpressionError = query.xpathExpressionError
        @emitter.emit 'did-change', @results
        return

      if query.results.length
        @results.push
          outline: query.outline
          results: query.results

    @emitter.emit 'did-change', @results