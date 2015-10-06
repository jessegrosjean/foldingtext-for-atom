{Disposable, CompositeDisposable} = require 'event-kit'
{stopEventPropagation} = require './util/dom'

class OutlineEditorElement extends HTMLElement

  createdCallback: ->
    @subscriptions = new CompositeDisposable
    @classList.add 'outline-editor'
    @setAttribute 'tabindex', -1

  attachedCallback: ->

  detachedCallback: ->
    @subscriptions.dispose()
    @editor.destroy()

  initializeContent: ->

  initialize: (@editor) ->
    this

  getEditor: ->
    @editor

  ###
  Section: Selection
  ###

  getSelectedRange: ->
    @getSelectedRanges()[0]

  setSelectedRange: (location, length) ->
    @setSelectedRanges([location: location, length: length])

  getSelectedRanges: ->
    []

  setSelectedRanges: (ranges) ->

  ###
  Section: Selection
  ###

  beginChanges: ->

  replaceRange: (location, length, string) ->

  endChanges: ->

  validateCommandMenuItem: (commandName, menuItem) ->
    switch commandName
      when 'core:undo'
        @editor.itemBuffer.outline.undoManager.canUndo()
      when 'core:redo'
        @editor.itemBuffer.outline.undoManager.canRedo()

atom.commands.add 'outline-editor', stopEventPropagation
  'core:undo': -> @editor.itemBuffer.outline.undoManager.undo()
  'core:redo': -> @editor.itemBuffer.outline.undoManager.redo()

  'core:cut': (e) -> @editor.cutSelection clipboardAsDatatransfer
  'core:copy': (e) -> @editor.copySelection clipboardAsDatatransfer
  'core:paste': (e) -> @editor.pasteToSelection clipboardAsDatatransfer

  'outline-editor:cut-opml': (e) -> @editor.cutSelection(clipboardAsDatatransfer, Constants.OPMLMimeType)
  'outline-editor:copy-opml': (e) -> @editor.copySelection(clipboardAsDatatransfer, Constants.OPMLMimeType)
  'outline-editor:paste-opml': (e) -> @editor.pasteToSelection(clipboardAsDatatransfer, Constants.OPMLMimeType)

  'outline-editor:cut-text': (e) -> @editor.cutSelection(clipboardAsDatatransfer, Constants.TEXTMimeType)
  'outline-editor:copy-text': (e) -> @editor.copySelection(clipboardAsDatatransfer, Constants.TEXTMimeType)
  'outline-editor:paste-text': (e) -> @editor.pasteToSelection(clipboardAsDatatransfer, Constants.TEXTMimeType)

  # Text Commands
  'editor:newline': -> @editor.insertNewline()
  'editor:newline-above': -> @editor.insertNewlineAbove()
  'editor:newline-below': -> @editor.insertNewlineBelow()
  'editor:newline-ignore-field-editor': -> @editor.insertNewlineIgnoringFieldEditor()
  'editor:line-break': -> @editor.insertLineBreak()
  'editor:indent': -> @editor.moveLinesRight()
  'editor:indent-selected-rows': -> @editor.moveLinesRight()
  'editor:outdent-selected-rows': -> @editor.moveLinesLeft()
  'editor:insert-tab-ignoring-field-editor': -> @editor.insertTabIgnoringFieldEditor()
  'editor:move-line-up': -> @editor.moveLinesUp()
  'editor:move-line-down': -> @editor.moveLinesDown()
  'editor:duplicate-lines': -> @editor.duplicateLines()

  # Outline Commands
  'outline-editor:move-branches-left': -> @editor.moveBranchesLeft()
  'outline-editor:move-branches-right': -> @editor.moveBranchesRight()
  'outline-editor:move-branches-up': -> @editor.moveBranchesUp()
  'outline-editor:move-branches-down': -> @editor.moveBranchesDown()
  'outline-editor:promote-child-branches': -> @editor.promoteChildBranches()
  'outline-editor:demote-trailing-sibling-branches': -> @editor.demoteTrailingSiblingBranches()
  'outline-editor:group-branches': -> @editor.groupBranches()

  # Text Formatting Commands
  'outline-editor:toggle-abbreviation': -> @editor.toggleFormattingTag 'ABBR'
  'outline-editor:toggle-bold': -> @editor.toggleFormattingTag 'B'
  'outline-editor:toggle-citation': -> @editor.toggleFormattingTag 'CITE'
  'outline-editor:toggle-code': -> @editor.toggleFormattingTag 'CODE'
  'outline-editor:toggle-definition': -> @editor.toggleFormattingTag 'DFN'
  'outline-editor:toggle-emphasis': -> @editor.toggleFormattingTag 'EM'
  'outline-editor:toggle-italic': -> @editor.toggleFormattingTag 'I'
  'outline-editor:toggle-keyboard-input': -> @editor.toggleFormattingTag 'KBD'
  'outline-editor:toggle-inline-quote': -> @editor.toggleFormattingTag 'Q'
  'outline-editor:toggle-strikethrough': -> @editor.toggleFormattingTag 'S'
  'outline-editor:toggle-sample-output': -> @editor.toggleFormattingTag 'SAMP'
  'outline-editor:toggle-small': -> @editor.toggleFormattingTag 'SMALL'
  'outline-editor:toggle-strong': -> @editor.toggleFormattingTag 'STRONG'
  'outline-editor:toggle-subscript': -> @editor.toggleFormattingTag 'SUB'
  'outline-editor:toggle-superscript': -> @editor.toggleFormattingTag 'SUP'
  'outline-editor:toggle-underline': -> @editor.toggleFormattingTag 'U'
  'outline-editor:toggle-variable': -> @editor.toggleFormattingTag 'VAR'
  'outline-editor:clear-formatting': -> @editor.clearFormatting()
  'editor:upper-case': -> @editor.upperCase()
  'editor:lower-case': -> @editor.lowerCase()

atom.commands.add 'outline-editor', stopEventPropagation
  'core:cancel': -> @editor.cancel()
  'editor:fold-all': -> @editor.foldAll()
  'editor:unfold-all': -> @editor.unfoldAll()
  'editor:fold-current-row': -> @editor.fold()
  'editor:unfold-current-row': -> @editor.unfold()
  'editor:fold-selection': -> @editor.fold()
  'editor:fold-at-indent-level-1': -> @editor.setFoldingLevel(0)
  'editor:fold-at-indent-level-2': -> @editor.setFoldingLevel(1)
  'editor:fold-at-indent-level-3': -> @editor.setFoldingLevel(2)
  'editor:fold-at-indent-level-4': -> @editor.setFoldingLevel(3)
  'editor:fold-at-indent-level-5': -> @editor.setFoldingLevel(4)
  'editor:fold-at-indent-level-6': -> @editor.setFoldingLevel(5)
  'editor:fold-at-indent-level-7': -> @editor.setFoldingLevel(6)
  'editor:fold-at-indent-level-8': -> @editor.setFoldingLevel(7)
  'editor:fold-at-indent-level-9': -> @editor.setFoldingLevel(8)
  'outline-editor:fold': -> @editor.fold()
  'outline-editor:fold-completely': -> @editor.foldCompletely()
  'outline-editor:increase-folding-level': -> @editor.increaseFoldingLevel()
  'outline-editor:decrease-folding-level': -> @editor.decreaseFoldingLevel()
  'outline-editor:hoist': -> @editor.hoist()
  'outline-editor:unhoist': -> @editor.unhoist()
  'outline-editor:open-link': -> @editor.openLink()
  'outline-editor:copy-link': -> @editor.copyLink()
  'outline-editor:edit-link': -> @editor.editLink()
  'outline-editor:remove-link': -> @editor.removeLink()
  'outline-editor:show-link-in-file-manager': -> @editor.showLinkInFileManager()
  'outline-editor:open-link-with-file-manager': -> @editor.openLinkWithFileManager()
  'editor:copy-path': -> @editor.copyPathToClipboard()

module.exports = OutlineEditorElement = document.registerElement 'outline-editor', prototype: OutlineEditorElement.prototype