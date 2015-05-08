# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

AttributedString = require '../core/attributed-string'

editLink = (outlineEditorElement) ->
  editor = outlineEditorElement.editor
  savedSelection = editor.selection
  item = savedSelection.focusItem
  offset = savedSelection.focusOffset
  return unless item

  linkAttributes
  if savedSelection.isCollapsed
    longestRange = {}
    linkAttributes = item.getElementAtBodyTextIndex('A', offset, null, longestRange)
    if linkAttributes?.href isnt undefined
      editor.moveSelectionRange(item, longestRange.location, item, longestRange.end)
      savedSelection = editor.selection
      offset = longestRange.location
  else
    linkAttributes = item.getElementAtBodyTextIndex('A', offset or 0)

  textInput = document.createElement 'ft-text-input'
  textInput.setText linkAttributes?.href or ''
  textInput.setPlaceholderText 'http://'

  textInput.setDelegate
    restoreFocus: ->
      editor.focus()
      editor.moveSelectionRange savedSelection

    cancelled: ->
      textInputPanel.destroy()

    confirm: ->
      linkText = textInput.getText()
      if savedSelection.isCollapsed
        insertText = new AttributedString linkText
        insertText.addAttributeInRange 'A', href: linkText, 0, linkText.length
        item.replaceBodyTextInRange insertText, offset, 0
        savedSelection = editor.createSelection item, offset, item, offset + linkText.length
      else
        editor._transformSelectedText (eachItem, start, end) ->
          if linkText
            eachItem.addElementInBodyTextRange('A', href: linkText, start, end - start)
          else
            eachItem.removeElementInBodyTextRange('A', start, end - start)
      textInputPanel.destroy()
      @restoreFocus()

  textInputPanel = atom.workspace.addPopoverPanel
    item: textInput
    className: 'ft-text-input-panel'
    target: -> editor.selection.selectionClientRect
    viewport: -> outlineEditorElement.getBoundingClientRect()

  textInput.focusTextEditor()

atom.commands.add 'ft-outline-editor',
  'outline-editor:edit-link': -> editLink this