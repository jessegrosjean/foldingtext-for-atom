# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

FoldingTextService = require '../foldingtext-service'
{Disposable, CompositeDisposable} = require 'atom'

class TextFormattingPopover extends HTMLElement
  constructor: ->
    super()

  createdCallback: ->
    @classList.add 'btn-toolbar'

    @formattingButtonGroup = document.createElement 'div'
    @formattingButtonGroup.classList.add 'btn-group'
    @appendChild @formattingButtonGroup

    @boldButton = document.createElement 'button'
    @boldButton.className = 'btn fa fa-bold fa-lg'
    @boldButton.setAttribute 'data-command', 'outline-editor:toggle-bold'
    @formattingButtonGroup.appendChild @boldButton

    @italicButton = document.createElement 'button'
    @italicButton.className = 'btn fa fa-italic fa-lg'
    @italicButton.setAttribute 'data-command', 'outline-editor:toggle-italic'
    @formattingButtonGroup.appendChild @italicButton

    @underlineButton = document.createElement 'button'
    @underlineButton.className = 'btn fa fa-underline fa-lg'
    @underlineButton.setAttribute 'data-command', 'outline-editor:toggle-underline'
    @formattingButtonGroup.appendChild @underlineButton

    @linkButton = document.createElement 'button'
    @linkButton.className = 'btn fa fa-link fa-lg'
    @linkButton.setAttribute 'data-command', 'outline-editor:edit-link'
    @formattingButtonGroup.appendChild @linkButton

    @clearFormattingButton = document.createElement 'button'
    @clearFormattingButton.className = 'btn fa fa-eraser fa-lg'
    @clearFormattingButton.setAttribute 'data-command', 'outline-editor:clear-formatting'
    @formattingButtonGroup.appendChild @clearFormattingButton

    ###
    @headingButton = document.createElement 'button'
    @headingButton.className = 'btn fa fa-header fa-lg'
    @headingButton.setAttribute 'data-command', 'outline-editor:edit-link'
    @formattingButtonGroup.appendChild @headingButton

    @statusButton = document.createElement 'button'
    @statusButton.className = 'btn fa fa-check fa-lg'
    @statusButton.setAttribute 'data-command', 'outline-editor:toggle-status-complete'
    @formattingButtonGroup.appendChild @statusButton

    @tagsButton = document.createElement 'button'
    @tagsButton.className = 'btn fa fa-tags fa-lg'
    @tagsButton.setAttribute 'data-command', 'outline-editor:edit-tags'
    @formattingButtonGroup.appendChild @tagsButton
    ###

  attachedCallback: ->
    @tooltipSubs = new CompositeDisposable
    @tooltipSubs.add atom.tooltips.add @boldButton,
      title: "Bold",
      keyBindingCommand: 'outline-editor:toggle-bold'
    @tooltipSubs.add atom.tooltips.add @italicButton,
      title: "Italic",
      keyBindingCommand: 'outline-editor:toggle-italic'
    @tooltipSubs.add atom.tooltips.add @underlineButton,
      title: "Underline",
      keyBindingCommand: 'outline-editor:edit-underline'
    @tooltipSubs.add atom.tooltips.add @linkButton,
      title: "Edit Link",
      keyBindingCommand: 'outline-editor:edit-link'
    @tooltipSubs.add atom.tooltips.add @clearFormattingButton,
      title: "Clear Formatting",
      keyBindingCommand: 'outline-editor:clear-formatting'

  detachedCallback: ->
    @tooltipSubs.dispose()

  validateButtons: ->
    formattingTags = FoldingTextService.getActiveOutlineEditor()?.getTypingFormattingTags() or {}

    unless @boldButton.classList.contains('selected') is formattingTags['B']?
      @boldButton.classList.toggle('selected')

    unless @italicButton.classList.contains('selected') is formattingTags['I']?
      @italicButton.classList.toggle('selected')

    unless @underlineButton.classList.contains('selected') is formattingTags['U']?
      @underlineButton.classList.toggle('selected')

    unless @linkButton.classList.contains('selected') is formattingTags['A']?
      @linkButton.classList.toggle('selected')

FoldingTextService.eventRegistery.listen 'ft-text-formatting-popover button',
  mousedown: (e) ->
    outlineEditorElement = FoldingTextService.getActiveOutlineEditor()?.outlineEditorElement
    if outlineEditorElement and command = e.target.getAttribute?('data-command')
      if command is 'outline-editor:edit-link'
        formattingBarPanel.hide()
      atom.commands.dispatch outlineEditorElement, command
      e.stopImmediatePropagation()
      e.stopPropagation()
      e.preventDefault()

formattingBar = document.createElement 'ft-text-formatting-popover'
formattingBarPanel = atom.workspace.addPopoverPanel
  item: formattingBar
  target: ->
    FoldingTextService.getActiveOutlineEditor()?.selection?.selectionClientRect
  viewport: ->
    FoldingTextService.getActiveOutlineEditor()?.outlineEditorElement.getBoundingClientRect()

FoldingTextService.observeActiveOutlineEditorSelection (selection) ->
  if selection?.isTextMode and not selection.isCollapsed and not selection.editor.outlineEditorElement.isPerformingExtendSelectionInteraction()
    formattingBarPanel.show()
    formattingBar.validateButtons()
  else
    formattingBarPanel.hide()

module.exports = document.registerElement 'ft-text-formatting-popover', prototype: TextFormattingPopover.prototype