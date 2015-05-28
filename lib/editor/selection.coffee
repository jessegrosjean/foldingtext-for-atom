# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

shallowEquals = require 'shallow-equals'
Item = require '../core/item'
assert = require 'assert'

ItemRenderer = null

# Public: The selection returned by {OutlineEditor::selection}.
#
# The anchor of a selection is the beginning point of the selection. When
# making a selection with a mouse, the anchor is where in the document the
# mouse button is initially pressed. As the user changes the selection using
# the mouse or the keyboard, the anchor does not move.
#
# The focus of a selection is the end point of the selection. When making a
# selection with a mouse, the focus is where in the document the mouse button
# is released. As the user changes the selection using the mouse or the
# keyboard, the focus is the end of the selection that moves.
#
# The start of a selection is the boundary closest to the beginning of the
# document. The end of a selection is the boundary closest to the end of the
# document.
class Selection

  @ItemAffinityAbove: 'ItemAffinityAbove'
  @ItemAffinityTopHalf: 'ItemAffinityTopHalf'
  @ItemAffinityBottomHalf: 'ItemAffinityBottomHalf'
  @ItemAffinityBelow: 'ItemAffinityBelow'

  @SelectionAffinityUpstream: 'SelectionAffinityUpstream'
  @SelectionAffinityDownstream: 'SelectionAffinityDownstream'

  ###
  Section: Anchor and Focus
  ###

  # Public: Read-only {Item} where the selection is anchored.
  anchorItem: null

  # Public: Read-only text offset in the anchor {Item} where the selection is anchored.
  anchorOffset: undefined

  # Public: Read-only {Item} where the selection is focused.
  focusItem: null

  # Public: Read-only text offset in the focus {Item} where the selection is focused.
  focusOffset: undefined

  ###
  Section: Start and End
  ###

  # Public: Read-only first selected {Item} in outline order.
  startItem: null

  # Public: Read-only text offset in the start {Item} where selection starts.
  startOffset: undefined

  # Public: Read-only last selected {Item} in outline order.
  endItem: null

  # Public: Read-only text offset in the end {Item} where selection end.
  endOffset: undefined

  ###
  Section: Items
  ###

  # Public: Read only {Array} of selected {Item}s.
  items: null

  # Public: Read only {Array} of common ancestors of selected {Item}s.
  itemsCommonAncestors: null

  @isUpstreamDirection: (direction) ->
    direction is 'backward' or direction is 'left' or direction is 'up'

  @isDownstreamDirection: (direction) ->
    direction is 'forward' or direction is 'right' or direction is 'down'

  @nextSelectionIndexFrom: (item, index, direction, granularity) ->
    text = item.bodyText

    assert(index >= 0 and index <= text.length, 'Invalid Index')

    if text.length is 0
      return 0

    iframe = document.getElementById('ft-text-calculation-frame')
    unless iframe
      iframe = document.createElement("iframe")
      iframe.id = 'ft-text-calculation-frame'
      document.body.appendChild(iframe)
      iframe.contentWindow.document.body.appendChild(iframe.contentWindow.document.createElement('P'))

    iframeWindow = iframe.contentWindow
    iframeDocument = iframeWindow.document
    selection = iframeDocument.getSelection()
    range = iframeDocument.createRange()
    iframeBody = iframeDocument.body
    p = iframeBody.firstChild

    p.textContent = text
    range.setStart(p.firstChild, index)
    selection.removeAllRanges()
    selection.addRange(range)
    selection.modify('move', direction, granularity)
    selection.focusOffset

  constructor: (editor, focusItem, focusOffset, anchorItem, anchorOffset, selectionAffinity) ->
    if focusItem instanceof Selection
      selection = focusItem
      editor = selection.editor
      focusItem = selection.focusItem
      focusOffset = selection.focusOffset
      anchorItem = selection.anchorItem
      anchorOffset = selection.anchorOffset
      selectionAffinity = selection.selectionAffinity

    @editor = editor
    @focusItem = focusItem or null
    @focusOffset = focusOffset
    @selectionAffinity = selectionAffinity or null
    @anchorItem = anchorItem or null
    @anchorOffset = anchorOffset

    unless anchorItem
      @anchorItem = @focusItem
      @anchorOffset = @focusOffset

    editor.makeVisible(anchorItem)
    editor.makeVisible(focusItem)

    unless @isValid
      @focusItem = null
      @focusOffset = undefined
      @anchorItem = null
      @anchorOffset = undefined

    @_calculateSelectionItems()

  ###
  Section: Selection State
  ###

  isValid: null
  Object.defineProperty @::, 'isValid',
    get: ->
      _isValidSelectionOffset(@editor, @focusItem, @focusOffset) and
      _isValidSelectionOffset(@editor, @anchorItem, @anchorOffset)

  # Public: Read-only indicating whether the selection's start and end points
  # are at the same position.
  isCollapsed: null
  Object.defineProperty @::, 'isCollapsed',
    get: -> @isTextMode and @focusOffset is @anchorOffset

  Object.defineProperty @::, 'isUpstreamAffinity',
    get: -> @selectionAffinity is Selection.SelectionAffinityUpstream

  Object.defineProperty @::, 'isOutlineMode',
    get: ->
      @isValid and (
        !!@anchorItem and
        !!@focusItem and
          (@anchorItem isnt @focusItem or
          @anchorOffset is undefined and @focusOffset is undefined)
      )

  Object.defineProperty @::, 'isTextMode',
    get: ->
      @isValid and (
        !!@anchorItem and
        @anchorItem is @focusItem and
        @anchorOffset isnt undefined and
        @focusOffset isnt undefined
      )

  Object.defineProperty @::, 'isReversed',
    get: ->
      focusItem = @focusItem
      anchorItem = @anchorItem

      if focusItem is anchorItem
        return (
          @focusOffset isnt undefined and
          @anchorOffset isnt undefined and
          @focusOffset < @anchorOffset
        )

      return (
        focusItem and
        anchorItem and
        !!(focusItem.comparePosition(anchorItem) & Node.DOCUMENT_POSITION_FOLLOWING)
      )

  Object.defineProperty @::, 'focusClientRect',
    get: -> @editor.getClientRectForItemOffset @focusItem, @focusOffset

  Object.defineProperty @::, 'anchorClientRect',
    get: -> @editor.getClientRectForItemOffset @anchorItem, @anchorOffset

  Object.defineProperty @::, 'selectionClientRect',
    get: -> @editor.getClientRectForItemRange @anchorItem, @anchorOffset, @focusItem, @focusOffset

  equals: (otherSelection) ->
    @focusItem is otherSelection.focusItem and
    @focusOffset is otherSelection.focusOffset and
    @anchorItem is otherSelection.anchorItem and
    @anchorOffset is otherSelection.anchorOffset and
    @selectionAffinity is otherSelection.selectionAffinity and
    shallowEquals(@items, otherSelection.items)

  contains: (item, offset) ->
    if item in @items
      if offset? and @isTextMode
        if item is @startItem and offset < @startOffset
          false
        else if item is @endItem and offset > @endOffset
          false
        else
          true
      else
        true
    else
      false

  selectionByExtending: (newFocusItem, newFocusOffset, newSelectionAffinity) ->
    new Selection(
      @editor,
      newFocusItem,
      newFocusOffset,
      @anchorItem,
      @anchorOffset,
      newSelectionAffinity or @selectionAffinity
    )

  selectionByModifying: (alter, direction, granularity) ->
    extending = alter is 'extend'
    next = @nextItemOffsetInDirection(direction, granularity, extending)

    if extending
      @selectionByExtending(next.offsetItem, next.offset, next.selectionAffinity);
    else
      new Selection(
        @editor,
        next.offsetItem,
        next.offset,
        next.offsetItem,
        next.offset,
        next.selectionAffinity
      )

  selectionByRevalidating: ->
    editor = @editor
    visibleItems = @items.filter (each) ->
      editor.isVisible each
    visibleSortedItems = visibleItems.sort (a, b) ->
      a.comparePosition(b) & Node.DOCUMENT_POSITION_PRECEDING

    if shallowEquals @items, visibleSortedItems
      return this

    focusItem = visibleSortedItems[0]
    anchorItem = visibleSortedItems[visibleSortedItems.length - 1]
    result = new Selection(
      @editor,
      focusItem,
      undefined,
      anchorItem,
      undefined,
      @selectionAffinity
    )

    result._calculateSelectionItems(visibleSortedItems)
    result

  nextItemOffsetInDirection: (direction, granularity, extending) ->
    if @isOutlineMode
      switch granularity
        when 'sentenceboundary', 'lineboundary', 'character', 'word', 'sentence', 'line'
          granularity = 'paragraphboundary'

    editor = @editor
    focusItem = @focusItem
    focusOffset = @focusOffset
    anchorOffset = @anchorOffset
    outlineEditorElement = @editor.outlineEditorElement
    upstream = Selection.isUpstreamDirection(direction)

    next =
      selectionAffinity: Selection.SelectionAffinityDownstream # All movements have downstream affinity except for line and lineboundary

    if focusItem
      unless extending
        focusItem = if upstream then @startItem else @endItem
      next.offsetItem = focusItem
    else
      next.offsetItem = if upstream then editor.getLastVisibleItem() else editor.getFirstVisibleItem()

    switch granularity
      when 'sentenceboundary'
        next.offset = Selection.nextSelectionIndexFrom(
          focusItem,
          focusOffset,
          if upstream then 'backward' else 'forward',
          granularity
        )

      when 'lineboundary'
        currentRect = editor.getClientRectForItemOffset focusItem, focusOffset
        if currentRect
          next = outlineEditorElement.pick(
            if upstream then Number.MIN_VALUE else Number.MAX_VALUE,
            currentRect.top + currentRect.height / 2.0
          ).itemCaretPosition

      when 'paragraphboundary'
        next.offset = if upstream then 0 else focusItem?.bodyText.length

      when 'character'
        if upstream
          if not @isCollapsed and not extending
            if focusOffset < anchorOffset
              next.offset = focusOffset
            else
              next.offset = anchorOffset
          else
            if focusOffset > 0
              next.offset = focusOffset - 1
            else
              prevItem = editor.getPreviousVisibleItem(focusItem)
              if prevItem
                next.offsetItem = prevItem
                next.offset = prevItem.bodyText.length
        else
          if not @isCollapsed and not extending
            if focusOffset > anchorOffset
              next.offset = focusOffset
            else
              next.offset = anchorOffset
          else
            if focusOffset < focusItem.bodyText.length
              next.offset = focusOffset + 1
            else
              nextItem = editor.getNextVisibleItem(focusItem)
              if nextItem
                next.offsetItem = nextItem
                next.offset = 0

      when 'word', 'sentence'
        next.offset = Selection.nextSelectionIndexFrom(
          focusItem,
          focusOffset,
          if upstream then 'backward' else 'forward',
          granularity
        )

        if next.offset is focusOffset
          nextItem = if upstream then editor.getPreviousVisibleItem(focusItem) else editor.getNextVisibleItem(focusItem)
          if nextItem
            direction = if upstream then 'backward' else 'forward'
            editorSelection = new Selection(@editor, nextItem, if upstream then nextItem.bodyText.length else 0)
            editorSelection = editorSelection.selectionByModifying('move', direction, granularity)
            next =
              offsetItem: editorSelection.focusItem
              offset: editorSelection.focusOffset
              selectionAffinity: editorSelection.selectionAffinity

      when 'line'
        next = @nextItemOffsetByLineFromFocus(focusItem, focusOffset, direction)

      when 'paragraph'
        prevItem = if upstream then editor.getPreviousVisibleItem(focusItem) else editor.getNextVisibleItem(focusItem)
        if prevItem
          next.offsetItem = prevItem

      when 'branch'
        prevItem = if upstream then editor.getPreviousVisibleBranch(focusItem) else editor.getNextVisibleBranch(focusItem)
        if prevItem
          next.offsetItem = prevItem

      when 'list'
        if upstream
          next.offsetItem = editor.getFirstVisibleChild(focusItem.parent)
          unless next.offsetItem
            next = @nextItemOffsetUpstream(direction, 'branch', extending)
        else
          next.offsetItem = editor.getLastVisibleChild(focusItem.parent)
          unless next.offsetItem
            next = @nextItemOffsetDownstream(direction, 'branch', extending)

      when 'parent'
        next.offsetItem = editor.getVisibleParent(focusItem)
        unless next.offsetItem
          next = @nextItemOffsetUpstream(direction, 'branch', extending)

      when 'firstchild'
        next.offsetItem = editor.getFirstVisibleChild(focusItem)
        unless next.offsetItem
          next = @nextItemOffsetDownstream(direction, 'branch', extending)

      when 'lastchild'
        next.offsetItem = editor.getLastVisibleChild(focusItem)
        unless next.offsetItem
          next = @nextItemOffsetDownstream(direction, 'branch', extending)

      when 'documentboundary'
        next.offsetItem = if upstream then editor.getFirstVisibleItem() else editor.getLastVisibleItem()

      else
        throw new Error 'Unexpected Granularity ' + granularity

    if not extending and not next.offsetItem
      next.offsetItem = focusItem

    if @isTextMode and next.offset is undefined
      next.offset = if upstream then 0 else next.offsetItem.bodyText.length

    next

  nextItemOffsetByLineFromFocus: (focusItem, focusOffset, direction) ->
    editor = @editor
    outlineEditorElement = editor.outlineEditorElement
    upstream = Selection.isUpstreamDirection(direction)
    renderedBodyText = outlineEditorElement.renderedBodyTextSPANForItem focusItem
    renderedBodyTextRect = renderedBodyText.getBoundingClientRect()
    renderedBodyTextStyle = window.getComputedStyle(renderedBodyText)
    viewLineHeight = parseInt(renderedBodyTextStyle.lineHeight, 10)
    viewPaddingTop = parseInt(renderedBodyTextStyle.paddingTop, 10)
    viewPaddingBottom = parseInt(renderedBodyTextStyle.paddingBottom, 10)
    focusCaretRect = editor.getClientRectForItemOffset(focusItem, focusOffset)
    x = editor.selectionVerticalAnchor()
    picked
    y

    if upstream
      y = focusCaretRect.bottom - (viewLineHeight * 1.5)
    else
      y = focusCaretRect.bottom + (viewLineHeight / 2.0)

    if y >= (renderedBodyTextRect.top + viewPaddingTop) and y <= (renderedBodyTextRect.bottom - viewPaddingBottom)
      picked = outlineEditorElement.pick(x, y).itemCaretPosition
    else
      nextItem

      if upstream
        nextItem = editor.getPreviousVisibleItem(focusItem)
      else
        nextItem = editor.getNextVisibleItem(focusItem)

      if nextItem
        editor.scrollToItemIfNeeded(nextItem) # pick breaks for offscreen items
        nextItemTextRect = outlineEditorElement.renderedBodyTextSPANForItem(nextItem).getBoundingClientRect()
        if upstream
          y = nextItemTextRect.bottom - 1
        else
          y = nextItemTextRect.top + 1
        picked = outlineEditorElement.pick(x, y).itemCaretPosition
      else
        if upstream
          picked =
            offsetItem: focusItem
            offset: 0
        else
          picked =
            offsetItem: focusItem
            offset: focusItem.bodyText.length
    picked

  _calculateSelectionItems: (overRideSelectionItems) ->
    items = overRideSelectionItems or []

    if @isValid and not overRideSelectionItems
      editor = @editor
      focusItem = @focusItem
      anchorItem = @anchorItem
      startItem = anchorItem
      endItem = focusItem

      if @isReversed
        startItem = focusItem
        endItem = anchorItem

      each = startItem
      while each
        items.push(each)
        if each is endItem
          break
        each = editor.getNextVisibleItem(each)

    @items = items
    @itemsCommonAncestors = Item.getCommonAncestors(items)
    @startItem = items[0]
    @endItem = items[items.length - 1]

    if @isReversed
      @startOffset = @focusOffset
      @endOffset = @anchorOffset
    else
      @startOffset = @anchorOffset
      @endOffset = @focusOffset

    if @isTextMode
      if @startOffset > @endOffset
        throw new Error 'Unexpected'

  toString: ->
    "anchor:#{@anchorItem?.id},#{@anchorOffset} focus:#{@focusItem?.id},#{@focusOffset}"

_isValidSelectionOffset = (editor, item, itemOffset) ->
  if item and editor.isVisible(item)
    if itemOffset is undefined
      true
    else
      itemOffset <= item.bodyText.length
  else
    false

module.exports = Selection