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
  'core:undo': (e) -> @editor.itemBuffer.outline.undoManager.undo()
  'core:redo': (e) -> @editor.itemBuffer.outline.undoManager.redo()

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
  'editor:newline': (e) -> @editor.insertNewline(e)
  'editor:newline-above': (e) -> @editor.insertNewlineAbove()
  'editor:newline-below': (e) -> @editor.insertNewlineBelow()
  'editor:newline-ignore-field-editor': (e) -> @editor.insertNewlineIgnoringFieldEditor()
  'editor:line-break': (e) -> @editor.insertLineBreak()
  'editor:indent': (e) -> @editor.moveLinesRight()
  'editor:indent-selected-rows': (e) -> @editor.moveLinesRight()
  'editor:outdent-selected-rows': (e) -> @editor.moveLinesLeft()
  'editor:insert-tab-ignoring-field-editor': (e) -> @editor.insertTabIgnoringFieldEditor()
  'editor:move-line-up': (e) -> @editor.moveLinesUp()
  'editor:move-line-down': (e) -> @editor.moveLinesDown()
  'editor:duplicate-lines': (e) -> @editor.duplicateLines()

  # Outline Commands
  'outline-editor:move-branches-left': (e) -> @editor.moveBranchesLeft()
  'outline-editor:move-branches-right': (e) -> @editor.moveBranchesRight()
  'outline-editor:move-branches-up': (e) -> @editor.moveBranchesUp()
  'outline-editor:move-branches-down': (e) -> @editor.moveBranchesDown()
  'outline-editor:delete-items': (e) -> @editor.deleteItems()
  'outline-editor:promote-child-branches': (e) -> @editor.promoteChildBranches()
  'outline-editor:demote-trailing-sibling-branches': (e) -> @editor.demoteTrailingSiblingBranches()
  'outline-editor:group-branches': (e) -> @editor.groupBranches()

  # Text Formatting Commands
  'outline-editor:toggle-abbreviation': (e) -> @editor.toggleFormattingTag 'ABBR'
  'outline-editor:toggle-bold': (e) -> @editor.toggleFormattingTag 'B'
  'outline-editor:toggle-citation': (e) -> @editor.toggleFormattingTag 'CITE'
  'outline-editor:toggle-code': (e) -> @editor.toggleFormattingTag 'CODE'
  'outline-editor:toggle-definition': (e) -> @editor.toggleFormattingTag 'DFN'
  'outline-editor:toggle-emphasis': (e) -> @editor.toggleFormattingTag 'EM'
  'outline-editor:toggle-italic': (e) -> @editor.toggleFormattingTag 'I'
  'outline-editor:toggle-keyboard-input': (e) -> @editor.toggleFormattingTag 'KBD'
  'outline-editor:toggle-inline-quote': (e) -> @editor.toggleFormattingTag 'Q'
  'outline-editor:toggle-strikethrough': (e) -> @editor.toggleFormattingTag 'S'
  'outline-editor:toggle-sample-output': (e) -> @editor.toggleFormattingTag 'SAMP'
  'outline-editor:toggle-small': (e) -> @editor.toggleFormattingTag 'SMALL'
  'outline-editor:toggle-strong': (e) -> @editor.toggleFormattingTag 'STRONG'
  'outline-editor:toggle-subscript': (e) -> @editor.toggleFormattingTag 'SUB'
  'outline-editor:toggle-superscript': (e) -> @editor.toggleFormattingTag 'SUP'
  'outline-editor:toggle-underline': (e) -> @editor.toggleFormattingTag 'U'
  'outline-editor:toggle-variable': (e) -> @editor.toggleFormattingTag 'VAR'
  'outline-editor:clear-formatting': (e) -> @editor.clearFormatting()
  'editor:upper-case': (e) -> @editor.upperCase()
  'editor:lower-case': (e) -> @editor.lowerCase()

atom.commands.add 'outline-editor', stopEventPropagation
  'core:cancel': (e) -> @editor.cancel()
  'editor:fold-all': (e) -> @editor.foldAll()
  'editor:unfold-all': (e) -> @editor.unfoldAll()
  'editor:fold-current-row': (e) -> @editor.fold()
  'editor:unfold-current-row': (e) -> @editor.unfold()
  'editor:fold-selection': (e) -> @editor.fold()
  'editor:fold-at-indent-level-1': (e) -> @editor.setFoldingLevel(0)
  'editor:fold-at-indent-level-2': (e) -> @editor.setFoldingLevel(1)
  'editor:fold-at-indent-level-3': (e) -> @editor.setFoldingLevel(2)
  'editor:fold-at-indent-level-4': (e) -> @editor.setFoldingLevel(3)
  'editor:fold-at-indent-level-5': (e) -> @editor.setFoldingLevel(4)
  'editor:fold-at-indent-level-6': (e) -> @editor.setFoldingLevel(5)
  'editor:fold-at-indent-level-7': (e) -> @editor.setFoldingLevel(6)
  'editor:fold-at-indent-level-8': (e) -> @editor.setFoldingLevel(7)
  'editor:fold-at-indent-level-9': (e) -> @editor.setFoldingLevel(8)
  'outline-editor:fold': (e) -> @editor.fold()
  'outline-editor:fold-completely': (e) -> @editor.foldCompletely()
  'outline-editor:increase-folding-level': (e) -> @editor.increaseFoldingLevel()
  'outline-editor:decrease-folding-level': (e) -> @editor.decreaseFoldingLevel()
  'outline-editor:hoist': (e) -> @editor.hoist()
  'outline-editor:unhoist': (e) -> @editor.unhoist()
  'outline-editor:open-link': (e) -> @editor.openLink()
  'outline-editor:copy-link': (e) -> @editor.copyLink()
  'outline-editor:edit-link': (e) -> @editor.editLink()
  'outline-editor:remove-link': (e) -> @editor.removeLink()
  'outline-editor:show-link-in-file-manager': (e) -> @editor.showLinkInFileManager()
  'outline-editor:open-link-with-file-manager': (e) -> @editor.openLinkWithFileManager()
  'outline-editor:select-item': (e) -> @editor.selectItem()
  'outline-editor:select-branch': (e) -> @editor.selectBranch()
  'editor:copy-path': (e) -> @editor.copyPathToClipboard()

module.exports = OutlineEditorElement = document.registerElement 'outline-editor', prototype: OutlineEditorElement.prototype
