# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

FoldingTextService = require '../../foldingtext-service'
{Disposable, CompositeDisposable} = require 'atom'

fuzzyFilter = null # defer until used

class ListInputElement extends HTMLElement

  items: []
  maxItems: Infinity
  allowNewItems: true
  allowMultipleItems: true
  allowEmptySelection: true
  scheduleTimeout: null
  inputThrottle: 50

  createdCallback: ->
    @insetPanel = document.createElement 'div'
    @insetPanel.classList.add 'inset-panel'

    @panelHeading = document.createElement 'div'
    @panelHeading.classList.add 'panel-heading'
    @panelHeading.textContent = 'hello heading'
    @insetPanel.appendChild @panelHeading

    @panelBody = document.createElement 'div'
    @panelBody.classList.add 'panel-body'
    @insetPanel.appendChild @panelBody

    @appendChild @insetPanel

    @classList.add 'select-list'
    @list = document.createElement 'ol'
    @list.classList.add 'list-group'

    @setTextInputElement document.createElement 'ft-text-input'

  attachedCallback: ->

  detachedCallback: ->

  attributeChangedCallback: (attrName, oldVal, newVal) ->

  ###
  Section: Text Input
  ###

  getTextInputElement: ->
    @textInputElement

  setTextInputElement: (textInputElement) ->
    if @textInputElement
      @textInputElement.parentElement.removeChild @textInputElement
    @textInputElement = textInputElement
    if @textInputElement
      @panelBody.insertBefore @textInputElement, @panelBody.firstChild
      @textInputElement.addAccessoryElement @list

  ###
  Section: Delegate
  ###

  getDelegate: ->
    @textInputElement.getDelegate()

  setDelegate: (delegate) ->
    originalDidChangeText = delegate.didChangeText?.bind(delegate)
    originalCanceled = delegate.canceled?.bind(delegate)

    delegate.didChangeText = (e) =>
      @schedulePopulateList()
      originalDidChangeText?(e)

    delegate.canceled = =>
      @list.innerHTML = ''
      originalCanceled?()

    @textInputElement.setDelegate(delegate)
    @populateList()

  ###
  Section: Text
  ###

  getFilterKey: ->

  getText: ->
    @textInputElement.getText()

  setText: (text) ->
    @textInputElement.setText text

  ###
  Section: Managing the list of items
  ###

  getSelectedItem: ->
    @getSelectedItemElement()?._item

  setSelectedItem: (item) ->
    @selectItemElement @getElementForItem item

  setItems: (@items=[]) ->
    @populateList()

  setMaxItems: (@maxItems) ->

  reloadItem: (item) ->
    if itemElement = @getElementForItem item
      newItemElement = @getDelegate().elementForListItem(item)
      newItemElement._item = item
      itemElement.parentElement.replaceChild(newItemElement, itemElement)

  populateList: ->
    return unless @items?

    selectedItem = @getSelectedItem()
    filterQuery = @getText()
    if filterQuery.length
      fuzzyFilter ?= require('fuzzaldrin').filter
      filteredItems = fuzzyFilter(@items, filterQuery, key: @getFilterKey())
    else
      filteredItems = @items

    @list.innerHTML = ''
    if filteredItems.length
      @list.style.display = null
      for i in [0...Math.min(filteredItems.length, @maxItems)]
        item = filteredItems[i]
        itemElement = @getDelegate().elementForListItem(item)
        itemElement._item = item
        @list.appendChild(itemElement)

      if selectedElement = @getElementForItem selectedItem
        @selectItemElement(selectedElement)
      else if not @allowEmptySelection
        @selectItemElement(@list.firstChild)
    else
      @list.style.display = 'none'

  ###
  Section: Allow Mark Active
  ###

  getAllowMarkActive: ->
    @allowMarkActive

  setAllowMarkActive: (allowMarkActive) ->
    unless @allowMarkActive is allowMarkActive
      @allowMarkActive = allowMarkActive
      if allowMarkActive
        @list.classList.add 'mark-active'
      else
        @list.classList.remove 'mark-active'

  ###
  Section: Messages to the user
  ###

  getEmptyMessage: (itemCount, filteredItemCount) ->
    emptyMessage = @getDelegate().getEmptyMessage?(itemCount, filteredItemCount)
    emptyMessage ?= 'No matches found'
    emptyMessage

  ###
  Section: Element Actions
  ###

  focusTextEditor: ->
    @textInputElement.focusTextEditor()

  ###
  Section: Private
  ###

  selectFirstElement: (e) ->
    @selectItemElement(@list.firstChild)
    @list.scrollTop = 0
    e?.stopImmediatePropagation()

  selectLastElement: (e) ->
    @selectItemElement(@list.lastChild)
    @list.scrollTop = @list.scrollHeight
    e?.stopImmediatePropagation()

  selectPreviousItemElement: (e) ->
    current = @getSelectedItemElement()
    previous = current?.previousSibling
    if not previous and not current
      previous = @list.lastChild
    if previous
      @selectItemElement(previous)
    e?.stopImmediatePropagation()

  selectNextItemElement: (e) ->
    current = @getSelectedItemElement()
    next = current?.nextSibling
    if not next and not current
      next = @list.firstChild
    if next
      @selectItemElement(next)
    e?.stopImmediatePropagation()

  selectItemElement: (element) ->
    oldSelected = @getSelectedItemElement()
    unless element is oldSelected
      delegate = @getDelegate()
      delegate.willSelectListItem?(element?._item)
      @getSelectedItemElement()?.classList.remove 'selected'
      if element and not element.classList.contains 'selected'
        element.classList.add('selected')
        @scrollToItemElement(element)
      delegate.didSelectListItem?(element?._item)

  clearListSelection: ->
    @selectItemElement(null)

  clearListSelectionOnTextMovement: ->
    @clearListSelection()

  scrollToItemElement: (element) ->
    scrollTop = @list.scrollTop
    listRect = @list.getBoundingClientRect()
    elementRect = element.getBoundingClientRect()
    if elementRect.bottom > listRect.bottom
      @list.scrollTop += (elementRect.bottom - listRect.bottom)
    else if elementRect.top < listRect.top
      @list.scrollTop += (elementRect.top - listRect.top)

  getSelectedItemElement: ->
    for each in @list.children
      if each.classList.contains 'selected'
        return each

  getElementForItem: (item) ->
    for each in @list.children
      if each._item is item
        return each

  schedulePopulateList: ->
    clearTimeout(@scheduleTimeout)
    populateCallback = =>
      @populateList() if document.contains(this)
    @scheduleTimeout = setTimeout(populateCallback,  @inputThrottle)

liForNode = (node) ->
  while node and node.tagName isnt 'LI'
    node = node.parentElement
  node

listInputForNode = (node) ->
  while node and node.tagName isnt 'FT-LIST-INPUT'
    node = node.parentElement
  node

FoldingTextService.eventRegistery.listen 'ft-list-input ft-text-input > atom-panel > .list-group',
  # This prevents the focusout event from firing on the filter editor element
  # when the list is scrolled by clicking the scrollbar and dragging.
  mousedown: (e) ->
    listInputForNode(this).selectItemElement(liForNode(e.target))
    e.preventDefault()
    e.stopPropagation()

  click: (e) ->
    listInput = listInputForNode(this)
    li = liForNode(e.target)
    if li?.classList.contains('selected')
      if listInput.getDelegate().mouseClickListItem
        listInput.getDelegate().mouseClickListItem(e)
    e.preventDefault()
    e.stopPropagation()

atom.commands.add 'ft-list-input ft-text-input > atom-text-editor[mini]',
  'core:move-up': (e) -> listInputForNode(this).selectPreviousItemElement(e)
  'core:move-down': (e) -> listInputForNode(this).selectNextItemElement(e)
  'core:move-to-top': (e) -> listInputForNode(this).selectFirstElement(e)
  'core:move-to-bottom': (e) -> listInputForNode(this).selectLastElement(e)

  'editor:move-to-first-character-of-line': (e) -> listInputForNode(this).clearListSelectionOnTextMovement(e)
  'editor:move-to-beginning-of-line': (e) -> listInputForNode(this).clearListSelectionOnTextMovement(e)
  'editor:move-to-beginning-of-paragraph': (e) -> listInputForNode(this).clearListSelectionOnTextMovement(e)
  'editor:move-to-beginning-of-word': (e) -> listInputForNode(this).clearListSelectionOnTextMovement(e)
  'core:move-backward': (e) -> listInputForNode(this).clearListSelectionOnTextMovement(e)
  'core:move-left': (e) -> listInputForNode(this).clearListSelectionOnTextMovement(e)
  'editor:move-to-end-of-word': (e) -> listInputForNode(this).clearListSelectionOnTextMovement(e)
  'core:move-forward': (e) -> listInputForNode(this).clearListSelectionOnTextMovement(e)
  'core:move-right': (e) -> listInputForNode(this).clearListSelectionOnTextMovement(e)
  'editor:move-to-end-of-screen-line': (e) -> listInputForNode(this).clearListSelectionOnTextMovement(e)
  'editor:move-to-end-of-line': (e) -> listInputForNode(this).clearListSelectionOnTextMovement(e)
  'editor:move-to-end-of-paragraph': (e) -> listInputForNode(this).clearListSelectionOnTextMovement(e)

module.exports = document.registerElement 'ft-list-input', prototype: ListInputElement.prototype