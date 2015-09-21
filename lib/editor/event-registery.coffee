# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

{Emitter, Disposable, CompositeDisposable} = require 'atom'
matchesSelector = require 'matches-selector'
{calculateSpecificity} = require 'clear-cut'

SequenceCount = 0
SpecificityCache = {}

class EventRegistery
  constructor: (@rootElement) ->
    @bubbleListenersByEventType = {}
    @captureListenersByEventType = {}
    @subscribers = new CompositeDisposable
    @emitter = new Emitter

  destroy: ->
    @subscribers.dispose()
    @subscribers = null

  listen: (target, eventType, callback, useCapture=false) ->
    if typeof eventType is 'object'
      events = eventType
      disposable = new CompositeDisposable
      for eventType, callback of events
        disposable.add @listen(target, eventType, callback, useCapture)
      return disposable

    if typeof target is 'string'
      @addSelectorBasedListener(target, eventType, callback, useCapture)
    else
      @addElementListener(target, eventType, callback, useCapture)

  addElementListener: (target, eventType, callback, useCapture) ->
    target.addEventListener(eventType, callback, useCapture)
    disposable = new Disposable =>
      target.removeEventListener(eventType, callback, useCapture)
      @subscribers.remove disposable
    @subscribers.add disposable
    disposable

  addSelectorBasedListener: (selector, eventType, callback, useCapture) ->
    listenersForEventType

    if useCapture
      @captureListenersByEventType[eventType] ?= []
      listenersForEventType = @captureListenersByEventType[eventType]
    else
      @bubbleListenersByEventType[eventType] ?= []
      listenersForEventType = @bubbleListenersByEventType[eventType]

    if listenersForEventType.length is 0
      @rootElement.addEventListener(eventType, @handleEvent, useCapture)

    listener = new SelectorBasedListener(selector, callback)
    listenersForEventType.push(listener)
    listenersForEventType.needsSort = true

    disposable = new Disposable =>
      listenersForEventType.splice(listenersForEventType.indexOf(listener), 1)
      if listenersForEventType.length is 0
        @rootElement.removeEventListener(eventType, @handleEvent, useCapture)
      @subscribers.remove disposable

    @subscribers.add disposable
    disposable

  onWillDispatch: (callback) ->
    @emitter.on 'will-dispatch', callback

  handleEvent: (event) =>
    eventType = event.type
    eventPhase = event.eventPhase
    captureListeners = @sortedListenersForEventType eventType, true
    bubbleListeners = @sortedListenersForEventType eventType, false
    listeners = []

    switch eventPhase
      when Event.CAPTURING_PHASE
        listeners = listeners.concat captureListeners
      when Event.AT_TARGET
        listeners = listeners.concat captureListeners
        listeners = listeners.concat bubbleListeners
      when Event.BUBBLING_PHASE
        listeners = listeners.concat bubbleListeners

    return unless listeners.length

    matched = false
    propagationStopped = false
    immediatePropagationStopped = false
    currentTarget = event.target
    rootElement = @rootElement
    {preventDefault, stopPropagation, stopImmediatePropagation, abortKeyBinding} = event

    Object.defineProperty event, 'preventDefault', value: ->
      preventDefault.call(this)
    Object.defineProperty event, 'stopPropagation', value: ->
      stopPropagation.call(this)
      propagationStopped = true
    Object.defineProperty event, 'stopImmediatePropagation', value: ->
      stopImmediatePropagation.call(this)
      propagationStopped = true
      immediatePropagationStopped = true
    Object.defineProperty event, 'abortKeyBinding', value: ->
      abortKeyBinding.call(this)

    dispatchedEvent = event

    @emitter.emit 'will-dispatch', dispatchedEvent

    while currentTarget and currentTarget.webkitMatchesSelector # second condiation a hack.. otherwise error when currentTarget is window
      for eachListener in listeners
        if matchesSelector(currentTarget, eachListener.selector)
          matched = true
          break if immediatePropagationStopped
          eachListener.callback.call(currentTarget, dispatchedEvent)

      break if propagationStopped
      break if currentTarget is rootElement
      currentTarget = currentTarget.parentElement ? window

    matched

  sortedListenersForEventType: (eventType, useCapture) ->
    listeners = if useCapture then @captureListenersByEventType[eventType] else @bubbleListenersByEventType[eventType]
    if listeners?.needsSort
      listeners.sort (a, b) -> a.compare(b)
      listeners.needsSort = false
    listeners or []

  stopEventPropagation: (commandListeners) ->
    newCommandListeners = {}
    for commandName, commandListener of commandListeners
      do (commandListener) ->
        newCommandListeners[commandName] = (event) ->
          event.stopPropagation()
          commandListener.call(this, event)
    newCommandListeners

  stopEventPropagationAndGroupUndo: (commandListeners) ->
    newCommandListeners = {}
    for commandName, commandListener of commandListeners
      do (commandListener) ->
        newCommandListeners[commandName] = (event) ->
          event.stopPropagation()
          commandListener.call(this, event)
    newCommandListeners

class SelectorBasedListener
  constructor: (@selector, @callback) ->
    @specificity = (SpecificityCache[@selector] ?= calculateSpecificity(@selector))
    @sequenceNumber = SequenceCount++

  compare: (other) ->
    other.specificity - @specificity  or
      other.sequenceNumber - @sequenceNumber

module.exports = new EventRegistery(document.body)
module.exports.EventRegistery = EventRegistery
