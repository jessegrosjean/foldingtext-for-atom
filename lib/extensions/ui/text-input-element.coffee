# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

FoldingTextService = require '../../foldingtext-service'
{Disposable, CompositeDisposable} = require 'atom'

fuzzyFilter = null # defer until used

class TextInputElement extends HTMLElement

  textEditor: null
  accessoryPanel: null
  cancelling: false
  cancelOnBlur: true
  delegate: null

  createdCallback: ->
    @textEditorElement = document.createElement 'atom-text-editor'
    @textEditorElement.setAttribute 'mini', true
    @textEditor = @textEditorElement.getModel()
    @appendChild @textEditorElement

    @leftAddons = []
    @rightAddons = []

    @message = document.createElement 'div'
    @appendChild @message

    @textEditor.onDidChangeSelectionRange (e) =>
      @delegate?.didChangeSelectionRange?(e) unless @cancelling

    @textEditor.onDidChangeSelectionRange (e) =>
      @delegate?.didChangeSelectionRange?(e) unless @cancelling

    @textEditor.onWillInsertText (e) =>
      @delegate?.willInsertText?(e) unless @cancelling

    @textEditor.onDidInsertText (e) =>
      @delegate?.didInsertText?(e) unless @cancelling

    @textEditor.onDidChange (e) =>
      if @sizeToFit
        @scheduleLayout()
      @delegate?.didChangeText?(e) unless @cancelling

    @textEditorElement.addEventListener 'blur', (e) =>
      if @cancelOnBlur
        @cancel(e) unless @cancelling

  attachedCallback: ->

  detachedCallback: ->

  attributeChangedCallback: (attrName, oldVal, newVal) ->

  ###
  Section: Messages to the user
  ###

  getPlaceholderText: ->
    @textEditor.getPlaceholderText()

  setPlaceholderText: (placeholderText) ->
    @textEditor.setPlaceholderText placeholderText

  setMessage: (message='') ->
    @message.innerHTML = ''
    if message.length is 0
      @message.style.display = 'none'
    else
      @message.textContent = message
      @message.style.display = null

  setHTMLMessage: (htmlMessage='') ->
    @message.innerHTML = ''
    if htmlMessage.length is 0
      @message.style.display = 'none'
    else
      @message.innerHTML = htmlMessage
      @message.style.display = null

  ###
  Section: Accessory Elements
  ###

  addAddon: (element, priority=0, addOnCollection) ->
    addon =
      element: element
      priority: priority

    addOnCollection.push addon
    addOnCollection.sort (a, b) ->
      a.priority - b.priority
    element.classList.add 'ft-text-input-addon'
    element.style.position = 'absolute'
    element.style.fontSize = 'inherit'
    element.style.lineHeight = 'inherit'
    @appendChild element
    @scheduleLayout()

    new Disposable =>
      addOnCollection.slice(addOnCollection.indexOf(addon), 1)
      element.parentElement.removeChild element
      @scheduleLayout()

  addLeftAddonElement: (element, priority=0) ->
    @addAddon element, priority, @leftAddons

  addRightAddonElement: (element, priority=0) ->
    @addAddon element, priority, @rightAddons

  addAccessoryElement: (element) ->
    unless @accessoryPanel
      @accessoryPanel = document.createElement 'atom-panel'
      @insertBefore @accessoryPanel, @textEditorElement.nextSibling
    @accessoryPanel.appendChild element
    new Disposable ->
      element.parentNode?.removeChild element

  ###
  Section: Text
  ###

  getText: ->
    @textEditor.getText()

  setText: (text) ->
    @textEditor.setText text or ''

  isCursorAtStart: ->
    range = @textEditor.getSelectedBufferRange()
    range.isEmpty() and range.containsPoint([0, 0])

  setGrammar: (grammar) ->
    @textEditor.setGrammar grammar

  ###
  Section: Layout
  ###

  scheduleLayout: ->
    unless @scheduleLayoutFrameID
      @scheduleLayoutFrameID = window.requestAnimationFrame =>
        @performLayout()

  performLayout: ->
    @scheduleLayoutFrameID = null

    @textEditorElement.style.paddingLeft = null
    @textEditorElement.style.paddingRight = null
    style = window.getComputedStyle(@textEditorElement)
    defaultPaddingLeft = parseFloat(style.paddingLeft, 10)
    defaultPaddingRight = parseFloat(style.paddingRight, 10)
    paddingLeft = defaultPaddingLeft
    paddingRight = defaultPaddingRight
    editorHeight = @textEditorElement.getBoundingClientRect().height

    # positions addons
    if @leftAddons.length
      for each in @leftAddons
        element = each.element
        eachRect = element.getBoundingClientRect()
        element.style.left = paddingLeft + 'px'
        element.style.top = ((editorHeight - eachRect.height) / 2) + 'px'
        paddingLeft += eachRect.width
        if eachRect.width
          paddingLeft += defaultPaddingLeft

    rightAddonsWidth = defaultPaddingRight
    for each in @rightAddons
      element = each.element
      eachRect = element.getBoundingClientRect()
      element.style.right = paddingRight + 'px'
      element.style.top = ((editorHeight - eachRect.height) / 2) + 'px'
      paddingRight += eachRect.width
      if eachRect.width
        paddingRight += defaultPaddingLeft

    @textEditorElement.style.paddingLeft = paddingLeft + 'px'
    @textEditorElement.style.paddingRight = paddingRight + 'px'

    if @sizeToFit
      firstLine = @textEditorElement.shadowRoot?.querySelector('.line')
      width = undefined

      if firstLine?.firstElementChild
        left = firstLine.firstElementChild.getBoundingClientRect().left
        right = firstLine.lastElementChild.getBoundingClientRect().right
        width = right - left
      else if placeHolder = @textEditorElement.shadowRoot?.querySelector('.placeholder-text')
        width = placeHolder.getBoundingClientRect().width

      if width?
        borderLeft = parseFloat style.borderLeftWidth
        paddingLeft = parseFloat style.paddingLeft
        paddingRight = parseFloat style.paddingRight
        borderRight = parseFloat style.borderRightWidth
        cursor = 2 # little extra so cursor isn't clipped in half
        @textEditorElement.style.width = Math.ceil(borderLeft + paddingLeft + width + paddingRight + borderRight + cursor) + 'px'

  setSizeToFit: (@sizeToFit) ->
    if @sizeToFit
      # Hack so that mini editor can never scroll backwards.
      @textEditorElement.component?.presenter?.constrainScrollLeft = -> 0
      @textEditorElement.component?.presenter?.setScrollLeft = -> 0
    else
      delete @textEditorElement.component?.presenter?.constrainScrollLeft
      delete @textEditorElement.component?.presenter?.setScrollLeft

    @scheduleLayout()

  ###
  Section: Delegate
  ###

  getDelegate: ->
    @delegate

  setDelegate: (@delegate) ->

  ###
  Section: Element Actions
  ###

  focusTextEditor: ->
    @textEditorElement.focus()

  cancel: (e) ->
    unless @cancelling
      if @delegate?.shouldCancel?
        unless @delegate.shouldCancel()
          e?.stopPropagation()
          return

    @cancelling = true
    textEditorElementFocused = @textEditorElement.hasFocus()
    @delegate?.cancelled?() unless @confirming
    @textEditor.setText('')
    @delegate?.restoreFocus?() if textEditorElementFocused
    @cancelling = false

  confirm: ->
    @confirming = true
    @delegate?.confirm?()
    @confirming = false

atom.commands.add 'ft-text-input > atom-text-editor[mini]',
  'core:confirm': (e) -> @parentElement.confirm(e)
  'core:cancel': (e) -> @parentElement.cancel(e)

module.exports = document.registerElement 'ft-text-input', prototype: TextInputElement.prototype