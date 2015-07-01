# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

ChildrenAnimation = require './animations/children-animation'
InsertAnimation = require './animations/insert-animation'
RemoveAnimation = require './animations/remove-animation'
AttributedString = require '../core/attributed-string'
MoveAnimation = require './animations/move-animation'
{Disposable, CompositeDisposable} = require 'atom'
Mutation = require '../core/mutation'
Velocity = require 'velocity-animate'
Selection = require './selection'
Util = require '../core/dom'

sortPriority = (a, b) ->
  if a.priority < b.priority
    -1
  else if a.priority > b.priority
    1
  else
    0

Velocity.Easings.ftEasing = (p, opts, tweenDelta) ->
  tension = 1.5
  friction = Math.log((Math.abs(tweenDelta) + 1) * 10)
  1 - Math.cos(p * tension * Math.PI) * Math.exp(-p * friction)

module.exports =
class ItemRenderer

  @DefaultAnimationContext:
    easing: 'ftEasing'
    duration: 400

  editor: null
  editorElement: null
  idsToLIs: null
  textRenderers: null
  badgeRenderers: null
  animations: null

  constructor: (@editor, @editorElement) ->
    @idsToLIs = {}
    @animations = {}
    @textRenderers = []
    @badgeRenderers = []

  destroy: ->
    @editor = null
    @editorElement = null
    @idsToLIs = null

  ###
  Section: Rendering
  ###

  renderItemLI: (item, depth) ->
    li = document.createElement 'LI'

    depth ?= item.depth
    li.setAttribute 'data-depth', depth

    for name in item.attributeNames
      if value = item.getAttribute name
        li.setAttribute name, value

    li.id = item.id
    li.className = @renderItemLIClasses item
    li.appendChild @renderBranchControlsDIV item
    li.appendChild @renderBranchDIV item, depth
    @idsToLIs[item.id] = li
    li

  renderItemLIClasses: (item) ->
    classes = ['ft-item']

    unless item.hasBodyText
      classes.push 'ft-no-body-text'

    if item.hasChildren
      classes.push 'ft-has-children'

    if @editor.isExpanded item
      classes.push 'ft-expanded'

    if @editor.isSelected item
      if @editor.selection.isTextMode
        classes.push 'ft-text-selected'
      else
        classes.push 'ft-item-selected'

    if @editor.getHoistedItem() is item
      classes.push 'ft-hoistedItem'

    if @editor.getDropParentItem() is item
      classes.push 'ft-drop-parent-item'

    if @editor.getDropInsertBeforeItem() is item
      classes.push 'ft-drop-before'

    if @editor.getDropInsertAfterItem() is item
      classes.push 'ft-drop-after'

    classes.join ' '

  renderBranchControlsDIV: (item) ->
    frame = document.createElement 'DIV'
    frame.className = 'ft-branch-controls'
    frame.appendChild @renderBranchHandleA item
    frame.appendChild @renderBranchBorderDIV item
    frame

  renderBranchHandleA: (item) ->
    handle = document.createElement 'A'
    handle.className = 'ft-handle'
    handle.draggable = true
    #ft-handle.tabIndex = -1
    handle

  renderBranchBorderDIV: (item) ->
    border = document.createElement 'DIV'
    border.className = 'ft-border'
    border

  renderBranchDIV: (item, depth) ->
    branch = document.createElement 'DIV'
    branch.className = 'ft-branch'
    branch.appendChild @renderItemContentP item
    if childrenUL = @renderChildrenUL item, depth
      branch.appendChild childrenUL
    branch

  renderItemContentP: (item) ->
    itemContent = document.createElement 'P'
    itemContent.className = 'ft-item-content'
    itemContent.appendChild @renderBodyTextSPAN item

    if badges = @renderBadgesSPAN item
      itemContent.appendChild badges
    itemContent

  renderBodyTextSPAN: (item) ->
    bodyText = document.createElement 'SPAN'
    bodyText.className = 'ft-body-text'
    bodyText.contentEditable = true
    bodyText.innerHTML = @renderBodyTextInnerHTML item
    bodyText

  renderBodyTextInnerHTML: (item) ->
    if @textRenderers
      renderedText = null
      for each in @textRenderers
        each.render item, (tagName, attributes, location, length) ->
          unless renderedText
            renderedText = item.attributedBodyText.copy()
          renderedText.addAttributeInRange tagName, attributes, location, length
      if renderedText
        p = document.createElement 'p'
        p.appendChild renderedText.toInlineFTMLFragment(document)
        p.innerHTML
      else
        item.bodyHTML
    else
      item.bodyHTML

  renderBadgesSPAN: (item) ->
    if @badgeRenderers
      badges = null
      for each in @badgeRenderers
        each.render item, (badgeElement) ->
          unless badges
            badges = document.createElement 'SPAN'
            badges.className = 'ft-badges'
          badgeElement.classList.add 'ft-badge'
          badges.appendChild badgeElement
      badges

  renderChildrenUL: (item, depth) ->
    if @editor.isExpanded(item) or @editor.getHoistedItem() is item
      depth ?= item.depth
      each = item.firstChild
      if each
        children = document.createElement 'UL'
        children.className = 'ft-children'
        while each
          if @editor.isVisible each
            children.appendChild @renderItemLI each, depth + 1
          each = each.nextSibling
        @updateItemChildrenGaps(item, children)
        children

  addBadgeRenderer: (callback, priority=0) ->
    renderer =
      priority: priority
      render: callback

    @badgeRenderers.push renderer
    @badgeRenderers.sort sortPriority

    new Disposable =>
      index = @badgeRenderers.indexOf renderer
      unless index is -1
        @badgeRenderers.splice index, 1

  addTextRenderer: (callback, priority=0) ->
    renderer =
      priority: priority
      render: callback

    @textRenderers.push renderer
    @textRenderers.sort sortPriority

    new Disposable =>
      index = @textRenderers.indexOf renderer
      unless index is -1
        @textRenderers.splice index, 1

  ###
  Section: Item Lookup
  ###

  itemForRenderedNode: (renderedNode) ->
    outline = @editor.outline
    while renderedNode
      if id = renderedNode.id
        if item = outline.getItemForID id
          return item
      renderedNode = renderedNode.parentNode

  ###
  Section: Rendered Node Lookup
  ###

  renderedLIForItem: (item) ->
    # Maintain our own idsToElements mapping instead of using getElementById
    # so that we can maintain two views of the same document in the same DOM.
    # The other approach would be to require use of Shadow DOM in that case,
    # but that brings lots of bagage and some performance issues with it.
    @idsToLIs[item?.id]

  renderedBodyTextSPANForItem: (item) ->
    ItemRenderer.renderedBodyTextSPANForRenderedLI(@renderedLIForItem(item))

  @renderedBranchDIVForRenderedLI: (LI) ->
    LI?.firstChild.nextSibling

  @renderedItemContentPForRenderedLI: (LI) ->
    @renderedBranchDIVForRenderedLI(LI)?.firstChild

  @renderedBodyTextSPANForRenderedLI: (LI) ->
    ItemRenderer.renderedItemContentPForRenderedLI(LI)?.firstChild

  @renderedBodyBadgesDIVForRenderedLI: (LI) ->
    ItemRenderer.renderedItemContentPForRenderedLI(LI)?.lastChild

  @renderedChildrenULForRenderedLI: (LI, createIfNeeded) ->
    branch = @renderedBranchDIVForRenderedLI LI
    if branch
      last = branch.lastChild
      if last.classList.contains 'ft-children'
        last
      else if createIfNeeded
        ul = document.createElement('UL')
        ul.className = 'ft-children'
        branch.appendChild ul
        ul

  ###
  Section: Updates
  ###

  prepareUpdateHoistedItem: (oldHoistedItem, newHoistedItem) ->
    unless oldHoistedItem
      return

    editor = @editor

    # Find the first item that's visiible in the old hoisted view and visible
    # in the new hoisted view. Iterate over visible items in old hoisted view
    # looking for first that's also visible in next hoisted view.
    start = oldHoistedItem.firstChild
    end = oldHoistedItem.nextBranch
    hoistCommonItem
    each = start

    while each and each isnt end and not hoistCommonItem
      if editor.isVisible each, oldHoistedItem
        if editor.isVisible each, newHoistedItem
          hoistCommonItem = each
        else
          each = each.nextItem
      else
        each = each.nextBranch

    # Couldn't find any currently visible item that's also visible in next
    # view. So instead search up through ancestors for common item.
    unless hoistCommonItem
      hoistCommonItem = editor.getFirstVisibleAncestorOrSelf oldHoistedItem, newHoistedItem

    @hoistAnchorItem = hoistCommonItem
    @hoistAnchorItemRect = @renderedLIForItem(hoistCommonItem)?.getBoundingClientRect()

  updateHoistedItem: (oldHoistedItem, newHoistedItem) ->
    editorElement = @editorElement
    editor = editorElement.editor
    topUL = editorElement.topListElement
    focused = editor.isFocused()
    topUL.innerHTML = ''
    @idsToLIs = {}

    if newHoistedItem
      topUL.appendChild @renderItemLI(newHoistedItem)
      if focused
        editor.focusIfNeeded()

    if editorElement.isAnimationEnabled()
      oldAnchorRect = @hoistAnchorItemRect
      newAnchorRect = @renderedLIForItem(@hoistAnchorItem)?.getBoundingClientRect()
      if oldAnchorRect and newAnchorRect
        editorElement.disableAnimation()
        editorElement.scrollTo(newAnchorRect.left - oldAnchorRect.left, newAnchorRect.top - oldAnchorRect.top, true)
        editorElement.enableAnimation()

    if @hoistAnchorItem and not oldHoistedItem.contains newHoistedItem
      # unhoist case, goal is to scroll up as far as possible such that new
      # anchorRect remains on screen and we do not scroll backward past zero.
      #@editorElement.scrollTo 0, Math.max(@editorElement.scrollTopWithOverscroll, 0)
      unhoistViewportTop = newHoistedItem?.getUserData(editor.id + '-unhoist-viewport-top')
      unless unhoistViewportTop is undefined
        @editorElement.scrollTo 0, unhoistViewportTop
      else
        @editorElement.scrollToItem @hoistAnchorItem, undefined, 'bottom'
    else
      @editorElement.scrollTo 0, 0

    @hoistAnchorItem = null
    @hoistAnchorItemRect = null

  updateItemClass: (item) ->
    @renderedLIForItem(item)?.className = @renderItemLIClasses item

  updateItemAttribute: (item, attributeName) ->
    renderedLI = @renderedLIForItem item
    if renderedLI
      if item.hasAttribute attributeName
        renderedLI.setAttribute attributeName, item.getAttribute(attributeName)
      else
        renderedLI.removeAttribute attributeName
      @updateItemBodyContent item

  updateItemBodyContent: (item) ->
    renderedLI = @renderedLIForItem item
    renderedBodyContentP = ItemRenderer.renderedItemContentPForRenderedLI renderedLI

    if renderedBodyContentP
      newHTML = @renderItemContentP(item).innerHTML
      if renderedBodyContentP.innerHTML isnt newHTML
        renderedBodyContentP.innerHTML = newHTML

  updateItemChildren: (item, removedChildren, addedChildren, nextSibling) ->
    renderedLI = @renderedLIForItem item
    if renderedLI
      renderedChildrenUL = ItemRenderer.renderedChildrenULForRenderedLI renderedLI
      animate = @editorElement.isAnimationEnabled()
      editor = @editor

      @updateItemClass item

      for eachChild in removedChildren
        eachChildRenderedLI = @renderedLIForItem eachChild
        if eachChildRenderedLI
          @disconnectBranchIDs eachChildRenderedLI
          if animate
            @animateRemoveRenderedItemLI eachChild, eachChildRenderedLI
          else
            renderedChildrenUL.removeChild eachChildRenderedLI

      # Only render added children if they aren't already present in the
      # outline. We are avoiding case where the update contains a number of
      # mutations, first adding a parent node, and then adding its children.
      # If we don't do this check the children end up getting added twice.
      childrenAlreadyVisible = @renderedLIForItem(addedChildren[0])?
      if addedChildren.length and not childrenAlreadyVisible
        childrenDepth = item.depth + 1
        nextVisibleSibling = nextSibling
        unless editor.isVisible nextSibling
          nextVisibleSibling = editor.getNextVisibleSibling nextSibling

        nextSiblingRenderedLI = @renderedLIForItem nextVisibleSibling
        documentFragment = document.createDocumentFragment()
        addedChildrenLIs = []

        for eachChild in addedChildren
          if editor.isVisible eachChild
            eachChildRenderedLI = @renderItemLI eachChild, childrenDepth
            addedChildrenLIs.push eachChildRenderedLI
            documentFragment.appendChild eachChildRenderedLI

        if not renderedChildrenUL
          renderedChildrenUL = ItemRenderer.renderedChildrenULForRenderedLI(renderedLI, true)

        renderedChildrenUL.insertBefore documentFragment, nextSiblingRenderedLI

        if animate
          outline = editor.outline
          for eachChildRenderedLI in addedChildrenLIs
            eachChildItem = outline.getItemForID eachChildRenderedLI.id
            @animateInsertRenderedItemLI eachChildItem, eachChildRenderedLI

      @updateItemChildrenGaps(item, renderedChildrenUL)

  updateRefreshItemChildren: (item) ->
    renderedLI = @renderedLIForItem item
    if renderedLI
      renderedChildrenUL = ItemRenderer.renderedChildrenULForRenderedLI renderedLI

      if renderedChildrenUL
        renderedChildrenUL.parentNode.removeChild renderedChildrenUL
        @disconnectBranchIDs renderedChildrenUL

      renderedChildrenUL = @renderChildrenUL item
      if renderedChildrenUL
        renderedLI.appendChild renderedChildrenUL

  updateItemChildrenGaps: (item, renderedChildrenUL) ->
    ###
    This isn't working well. For one it's two hard to style and maybe not performant.
    Maybe better would be a "line numbers" style gutter that indicated folded regions.
    Might be generally useful, and would also be easily clickable.
    ###

    ###
    eachChild = item.firstChild
    eachChildLI = renderedChildrenUL?.firstElementChild
    editor = @editor
    outline = editor.outline
    gap = false

    while eachChildLI
      eachChild = outline.getItemForID(eachChildLI.id)
      previousID = eachChild.previousSibling?.id
      previousVisibleID = eachChildLI.previousSibling?.id

      if previousID isnt previousVisibleID
        eachChildLI.classList.add('ft-gap-before')
      else
        eachChildLI.classList.remove('ft-gap-before')

      nextID = eachChild.nextSibling?.id
      nextVisibleID = eachChildLI.nextSibling?.id

      if nextID isnt nextVisibleID
        eachChildLI.classList.add('ft-gap-after')
      else
        eachChildLI.classList.remove('ft-gap-after')

      eachChildLI = eachChildLI.nextSibling
    ###

  updateItemExpanded: (item) ->
    @updateItemClass item

    renderedLI = @renderedLIForItem item
    if renderedLI
      animate = @editorElement.isAnimationEnabled()
      renderedChildrenUL = ItemRenderer.renderedChildrenULForRenderedLI renderedLI

      if renderedChildrenUL
        if animate
          @animateCollapseRenderedChildrenUL item, renderedChildrenUL
        else
          renderedChildrenUL.parentNode.removeChild renderedChildrenUL
        @disconnectBranchIDs renderedChildrenUL

      renderedChildrenUL = @renderChildrenUL item
      if renderedChildrenUL
        renderedBranchDIV = ItemRenderer.renderedBranchDIVForRenderedLI renderedLI
        renderedBranchDIV.appendChild renderedChildrenUL
        if animate
          @animateExpandRenderedChildrenUL item, renderedChildrenUL

  outlineDidChange: (mutations) ->
    for each in mutations
      switch each.type
        when Mutation.ATTRIBUTE_CHANGED
          @updateItemAttribute each.target, each.attributeName
        when Mutation.BODT_TEXT_CHANGED
          @updateItemBodyContent each.target
        when Mutation.CHILDREN_CHANGED
          @updateItemChildren(
            each.target,
            each.removedItems,
            each.addedItems,
            each.nextSibling
          )
        else
          throw new Error 'Unexpected Change Type'

  ###
  Section: Animations
  ###

  completedAnimation: (id) ->
    delete @animations[id]

  animationForItem: (item, clazz) ->
    animationID = item.id + clazz.id
    animation = @animations[animationID]
    if not animation
      animation = new clazz animationID, item, this
      @animations[animationID] = animation
    animation

  animateExpandRenderedChildrenUL: (item, renderedLI) ->
    @animationForItem(item, ChildrenAnimation).expand renderedLI, ItemRenderer.DefaultAnimationContext

  animateCollapseRenderedChildrenUL: (item, renderedLI) ->
    @animationForItem(item, ChildrenAnimation).collapse renderedLI, ItemRenderer.DefaultAnimationContext

  animateInsertRenderedItemLI: (item, renderedLI) ->
    @animationForItem(item, InsertAnimation).insert renderedLI, ItemRenderer.DefaultAnimationContext

  animateRemoveRenderedItemLI: (item, renderedLI) ->
    @animationForItem(item, RemoveAnimation).remove renderedLI, ItemRenderer.DefaultAnimationContext

  renderedItemLIPosition: (renderedLI) ->
    renderedPRect = ItemRenderer.renderedBodyTextSPANForRenderedLI(renderedLI).getBoundingClientRect()
    animationRect = @editorElement.itemAnimationLayerElement.getBoundingClientRect()
    renderedLIRect = renderedLI.getBoundingClientRect()
    {} =
      top: renderedLIRect.top - animationRect.top
      bottom: renderedPRect.bottom - animationRect.bottom
      left: renderedLIRect.left - animationRect.left
      width: renderedLIRect.width

  animateMoveItems: (items, newParent, newNextSibling, startOffset) ->
    if items.length is 0
      return

    editor = @editor
    outline = editor.outline
    animate = @editorElement.isAnimationEnabled()
    savedSelectionRange = editor.selection
    hoistedItem = editor.getHoistedItem()
    animations = @animations

    # Complete all existing animations
    for own key, animation of animations
      animation.complete() if animation.complete

    if animate
      for each in items
        renderedLI = @renderedLIForItem each
        if renderedLI
          startPosition = @renderedItemLIPosition renderedLI
          if startOffset
            startPosition.left += startOffset.xOffset
            startPosition.top += startOffset.yOffset
            startPosition.bottom += startOffset.yOffset
          @animationForItem(each, MoveAnimation).beginMove renderedLI, startPosition

    firstItem = items[0]
    lastItem = items[items.length - 1]
    firstItemParent = firstItem.parent
    firstItemParentParent = firstItemParent?.parent
    newParentNeedsExpand =
      newParent isnt hoistedItem and
      not editor.isExpanded(newParent) and
      editor.isVisible(newParent)

    # Special case indent and unindent indentations when vertical position of
    # fist item won't change. In those cases disable all animations except
    # for the slide
    disableAnimation =
      (newParent is editor.getPreviousVisibleSibling(firstItem) and
       not newNextSibling and
        (not newParentNeedsExpand or
         not newParent.firstChild)) or
      (newParent is firstItemParentParent and
       firstItemParent is lastItem.parent and
       editor.getLastVisibleChild(lastItem.parent) is lastItem)

    if disableAnimation
      @editorElement.disableAnimation()

    outline.beginUpdates()
    outline.removeItemsFromParents items
    newParent.insertChildrenBefore items, newNextSibling
    outline.endUpdates()

    if newParentNeedsExpand
      editor.setExpanded newParent

    if disableAnimation
      @editorElement.enableAnimation()

    editor.moveSelectionRange savedSelectionRange

    # Fast temporarily forward all animations to final position. Animation
    # system will automatically continue normal animations on next tick.
    for own key, animation of animations
      animation.fastForward ItemRenderer.DefaultAnimationContext

    scrollToTop = Number.MAX_VALUE
    scrollToBottom = Number.MIN_VALUE

    if animate
      for each in items
        animation = animations[each.id + MoveAnimation.id]
        renderedLI = @renderedLIForItem each

        if animation
          position = @renderedItemLIPosition renderedLI, true
          scrollToTop = Math.min position.top, scrollToTop
          scrollToBottom = Math.max position.bottom, scrollToBottom
          animation.performMove renderedLI, position, ItemRenderer.DefaultAnimationContext

    if scrollToTop isnt Number.MAX_VALUE
      @editorElement.scrollToOffsetRangeIfNeeded scrollToTop, scrollToBottom, true

  ###
  Section: Picking
  ###

  pick: (clientX, clientY, LI) ->
    LI ?= @editorElement.topListElement.firstChild
    UL = ItemRenderer.renderedChildrenULForRenderedLI LI

    if UL
      itemContentP = ItemRenderer.renderedItemContentPForRenderedLI LI
      itemContentRect = itemContentP.getBoundingClientRect()
      if itemContentRect.height > 0 and clientY < itemContentRect.bottom
        @pickBodyTextSPAN clientX, clientY, ItemRenderer.renderedBodyTextSPANForRenderedLI LI
      else
        children = UL.children
        length = children.length

        if length is 0
          return null

        high = length - 1
        low = 0

        while low <= high
          i = Math.floor((low + high) / 2)
          childLI = children.item i
          childLIRect = childLI.getBoundingClientRect()
          if clientY < childLIRect.top
            high = i - 1
          else if clientY > childLIRect.bottom
            low = i + 1
          else
            return @pick clientX, clientY, childLI

        @pick clientX, clientY, childLI
    else
      @pickBodyTextSPAN clientX, clientY, ItemRenderer.renderedBodyTextSPANForRenderedLI LI

  pickBodyTextSPAN: (clientX, clientY, renderedBodyTextSPAN) ->
    item = @itemForRenderedNode renderedBodyTextSPAN
    bodyTextRect = renderedBodyTextSPAN.getBoundingClientRect()
    bodyTextRectMid = bodyTextRect.top + (bodyTextRect.height / 2.0)
    itemAffinity

    if clientY < bodyTextRect.top
      itemAffinity = Selection.ItemAffinityAbove
      if item is @editor.getFirstVisibleItem()
        clientX = Number.MIN_VALUE
    else if clientY < bodyTextRectMid
      itemAffinity = Selection.ItemAffinityTopHalf
    else if clientY > bodyTextRect.bottom
      itemAffinity = Selection.ItemAffinityBelow
      if item is @editor.getLastVisibleItem()
        clientX = Number.MAX_VALUE
    else
      itemAffinity = Selection.ItemAffinityBottomHalf

    # Constrain pick point inside the text rect so that we'll get a good
    # 3 pick result.

    style = window.getComputedStyle renderedBodyTextSPAN
    paddingTop = parseInt(style.paddingTop, 10)
    paddingBottom = parseInt(style.paddingBottom, 10)
    lineHeight = parseInt(style.lineHeight, 10)
    halfLineHeight = lineHeight / 2.0
    bodyTop = Math.ceil(bodyTextRect.top)
    bodyBottom = Math.ceil(bodyTextRect.bottom)
    pickableBodyTop = bodyTop + halfLineHeight + paddingTop
    pickableBodyBottom = bodyBottom - (halfLineHeight + paddingBottom)

    if clientY <= pickableBodyTop
      clientY = pickableBodyTop
    else if clientY >= pickableBodyBottom
      clientY = pickableBodyBottom

    # Magic nubmer is "1" for x values, any more and we miss l's at the
    # end of the line.

    if clientX <= bodyTextRect.left
      clientX = Math.ceil(bodyTextRect.left) + 1
    else if clientX >= bodyTextRect.right
      clientX = Math.floor(bodyTextRect.right) - 1

    nodeCaretPosition = @caretPositionFromPoint(clientX, clientY)
    if nodeCaretPosition
      offset = AttributedString.inlineFTMLOffsetToTextOffset(nodeCaretPosition.offsetItem, nodeCaretPosition.offset)
    else
      offset = 0

    if offset is undefined
      offset = item.bodyText.length

    itemCaretPosition =
      offsetItem: item
      offset: offset
      selectionAffinity: if nodeCaretPosition then nodeCaretPosition.selectionAffinity else Selection.SelectionAffinityUpstream
      itemAffinity: itemAffinity

    return {} =
      nodeCaretPosition: nodeCaretPosition
      itemCaretPosition: itemCaretPosition

  caretPositionFromPoint: (clientX, clientY) ->
    pick = @editor.DOMCaretPositionFromPoint clientX, clientY
    range = pick?.range
    clientRects = range?.getClientRects()
    length = clientRects?.length

    if length > 1
      upstreamRect = clientRects[0]
      downstreamRect = clientRects[1]
      upstreamDist = Math.abs(upstreamRect.left - clientX)
      downstreamDist = Math.abs(downstreamRect.left - clientX)
      if downstreamDist < upstreamDist
        pick.selectionAffinity = Selection.SelectionAffinityDownstream
      else
        pick.selectionAffinity = Selection.SelectionAffinityUpstream
    else
      if range?.startOffset is 0
        pick?.selectionAffinity = Selection.SelectionAffinityDownstream
      else
        pick?.selectionAffinity = Selection.SelectionAffinityUpstream

    pick

  ###
  Section: Offset Mapping
  ###

  itemOffsetToNodeOffset: (item, offset) ->
    renderedLI = @renderedLIForItem item
    renderedBodyTextSPAN = ItemRenderer.renderedBodyTextSPANForRenderedLI renderedLI
    AttributedString.textOffsetToInlineFTMLOffset offset, renderedBodyTextSPAN

  ###
  Section: Util
  ###

  disconnectBranchIDs: (element) ->
    end = Util.nodeNextBranch(element)
    idsToLIs = @idsToLIs
    each = element
    while each isnt end
      if each.id
        delete idsToLIs[each.id]
        each.removeAttribute('id')
      each = Util.nextNode(each)