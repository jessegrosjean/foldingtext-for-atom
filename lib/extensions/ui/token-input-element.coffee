# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

FoldingTextService = require '../../foldingtext-service'
{Disposable, CompositeDisposable} = require 'atom'
TextInputElement = require './text-input-element'

class TokenInputElement extends HTMLElement

  textInputElement: null

  createdCallback: ->
    @tokenzieRegex = /\s|,|#/

    @list = document.createElement 'ol'
    @appendChild @list

    @textInputElement = document.createElement 'ft-text-input'
    @textEditorElement = @textInputElement.textEditorElement
    @textEditor = @textInputElement.textEditor
    @appendChild @textInputElement

    @updateLayout()

  attachedCallback: ->
    @updateLayout()
    setTimeout =>
      @updateLayout()

  detachedCallback: ->

  attributeChangedCallback: (attrName, oldVal, newVal) ->

  ###
  Section: Messages to the user
  ###

  getPlaceholderText: ->
    @textInputElement.getPlaceholderText()

  setPlaceholderText: (placeholderText) ->
    @textInputElement.setPlaceholderText placeholderText

  setMessage: (message='') ->
    @textInputElement.setMessage message

  setHTMLMessage: (htmlMessage='') ->
    @textInputElement.setHTMLMessage htmlMessage

  ###
  Section: Accessory Elements
  ###

  addAccessoryElement: (element) ->
    @textInputElement.addAccessoryElement element

  ###
  Section: Text
  ###

  getText: ->
    @textInputElement.getText()

  setText: (text) ->
    @textInputElement.setText text

  ###
  Section: Delegate
  ###

  getDelegate: ->
    @textInputElement.getDelegate()

  setDelegate: (delegate) ->
    originalDidInsertText = delegate.didInsertText?.bind(delegate)

    delegate.didInsertText = (e) =>
      @setSelectedToken(null)
      if e.text.match(@tokenzieRegex)
        @setSelectedToken(null)
        @tokenizeText()
      originalDidInsertText?(e)

    @textInputElement.setDelegate(delegate)

  ###
  Section: Tokens
  ###

  getTokens: ->
    tokens = []
    for each in @list.children
      tokens.push each.textContent
    tokens

  hasToken: (token) ->
    !! @getElementForToken token

  toggleToken: (token) ->
    if @hasToken token
      @deleteToken token
    else
      @tokenizeText token

  deleteToken: (token) ->
    @deleteTokenElement @getElementForToken token

  getSelectedToken: ->
    @getSelectedTokenElement()?._token

  setSelectedToken: (token) ->
    @selectTokenElement @getElementForToken token

  tokenizeText: (text) ->
    text ?= @getText() or ''
    if text
      delegate = @getDelegate()
      tokens = (token for token in text.split(/\s|,|#/) when token.length > 0)
      for each in tokens
        delegate?.willAddToken?(each)
        tokenElement = document.createElement 'li'
        tokenElement.textContent = each
        tokenElement._token = each
        @list.appendChild(tokenElement)
        delegate?.didAddToken?(each)

      @setText('')
      @updateLayout()

  ###
  Section: Element Actions
  ###

  focusTextEditor: ->
    @textInputElement.focusTextEditor()

  ###
  Section: Private
  ###

  moveToStart: (e) ->
    @tokenizeText()
    @selectTokenElement @list.firstChild

  moveToEnd: (e) ->
    @setSelectedToken null

  moveBackward: (e) ->
    if @textInputElement.isCursorAtStart()
      @selectPreviousTokenElement()
      @tokenizeText()

  moveForward: (e) ->
    if @textInputElement.isCursorAtStart()
      @selectNextTokenElement()

  deleteTokenElement: (element) ->
    return unless element

    token = element.textContent
    delegate = @getDelegate()
    delegate?.willDeleteToken?(token)
    element.parentElement.removeChild element
    delegate?.didDeleteToken?(token)
    @updateLayout()

  delete: (e, backspace) ->
    if backspace and not @textInputElement.isCursorAtStart()
      return

    if selected = @getSelectedTokenElement()
      if backspace
        @selectTokenElement(selected.previousSibling or selected.nextSibling)
      else
        @selectTokenElement(selected.nextSibling or selected.previousSibling)
      @deleteTokenElement selected
    else if backspace
      @selectPreviousTokenElement()
      @tokenizeText()

  selectPreviousTokenElement: ->
    current = @getSelectedTokenElement()
    previous = current?.previousSibling
    if not previous and not current
      previous = @list.lastChild
    if previous
      @selectTokenElement(previous)

  selectNextTokenElement: ->
    current = @getSelectedTokenElement()
    next = current?.nextSibling
    @selectTokenElement(next)

  selectTokenElement: (element) ->
    oldSelected = @getSelectedTokenElement()
    unless element is oldSelected
      token = element?.textContent
      delegate = @getDelegate()
      delegate?.willSelectToken?(token)
      oldSelected?.classList.remove 'selected'
      if element
        element.classList.add('selected')
        @classList.add 'has-token-selected'
      else
        @classList.remove 'has-token-selected'
        @textEditorElement.component?.presenter?.pauseCursorBlinking?() # Hack
      delegate?.didSelectToken?(token)

  getSelectedTokenElement: ->
    for each in @list.children
      if each.classList.contains 'selected'
        return each

  getElementForToken: (token) ->
    for each in @list.children
      if each._token is token
        return each

  updateLayout: ->
    @list.style.top = null
    @list.style.left = null
    @list.style.width = null

    @textEditorElement.style.paddingTop = null
    @textEditorElement.style.paddingLeft = null
    textEditorComputedStyle = window.getComputedStyle(@textEditorElement)
    defaultPaddingLeft = parseFloat(textEditorComputedStyle.paddingLeft, 10)
    defaultPaddingTop = parseFloat(textEditorComputedStyle.paddingTop, 10)

    editorRect = @textEditorElement.getBoundingClientRect()
    tokensRect = @list.getBoundingClientRect()
    padTop = false

    if tokensRect.width > editorRect.width
      @list.style.width = editorRect.width + 'px'
      tokensRect = @list.getBoundingClientRect()
      padTop = true

    # Vertical Align
    topOffset = editorRect.top - tokensRect.top
    if padTop
      @textEditorElement.style.paddingTop = (tokensRect.height) + 'px'
    else
      topOffset += ((editorRect.height / 2) - (tokensRect.height / 2))
    @list.style.top = topOffset + 'px'

    # Horizontal Align
    @list.style.left = defaultPaddingLeft + 'px'
    if tokensRect.width
      @textEditorElement.style.paddingLeft = (tokensRect.width + (defaultPaddingLeft * 1.25)) + 'px'

FoldingTextService.eventRegistery.listen 'ft-token-input > ol > li',
  mousedown: (e) ->
    tokenInput = @parentElement.parentElement
    tokenInput.tokenizeText()
    tokenInput.selectTokenElement this
    e.stopImmediatePropagation()
    e.stopPropagation()
    e.preventDefault()

  click: (e) ->
    e.stopImmediatePropagation()
    e.stopPropagation()
    e.preventDefault()

FoldingTextService.eventRegistery.listen 'ft-token-input > ft-text-input > atom-text-editor[mini]',
  mousedown: (e) ->
    @parentElement.parentElement.setSelectedToken null

atom.commands.add 'ft-token-input > ft-text-input > atom-text-editor[mini]',
  'editor:move-to-first-character-of-line': (e) -> @parentElement.parentElement.moveToStart(e)
  'editor:move-to-beginning-of-line': (e) -> @parentElement.parentElement.moveToStart(e)
  'editor:move-to-beginning-of-paragraph': (e) -> @parentElement.parentElement.moveToStart(e)

  'editor:move-to-beginning-of-word': (e) -> @parentElement.parentElement.moveBackward(e)
  'core:move-backward': (e) -> @parentElement.parentElement.moveBackward(e)
  'core:move-left': (e) -> @parentElement.parentElement.moveBackward(e)

  'editor:move-to-end-of-word': (e) -> @parentElement.parentElement.moveForward(e)
  'core:move-forward': (e) -> @parentElement.parentElement.moveForward(e)
  'core:move-right': (e) -> @parentElement.parentElement.moveForward(e)

  'editor:move-to-end-of-screen-line': (e) -> @parentElement.parentElement.moveToEnd(e)
  'editor:move-to-end-of-line': (e) -> @parentElement.parentElement.moveToEnd(e)
  'editor:move-to-end-of-paragraph': (e) -> @parentElement.parentElement.moveToEnd(e)

  'core:move-up': (e) -> @parentElement.parentElement.moveToStart(e)
  'core:move-to-top': (e) -> @parentElement.parentElement.moveToStart()
  'core:move-down': (e) -> @parentElement.parentElement.moveToEnd(e)
  'core:move-to-bottom': (e) -> @parentElement.parentElement.moveToEnd(e)

  'core:delete': (e) -> @parentElement.parentElement.delete(e, false)
  'core:backspace': (e) -> @parentElement.parentElement.delete(e, true)

module.exports = document.registerElement 'ft-token-input', prototype: TokenInputElement.prototype