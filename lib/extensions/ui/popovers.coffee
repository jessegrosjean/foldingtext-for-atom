# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

panelContainerPath = atom.config.resourcePath + '/src/panel-container'
PanelContainer = require panelContainerPath
panelElementPath = atom.config.resourcePath + '/src/panel-element'
PanelElement = require panelElementPath

atom.workspace.panelContainers.popover = new PanelContainer({location: 'popover'})
workspaceElement = atom.views.getView(atom.workspace)
workspaceElement.panelContainers.popover = atom.views.getView(atom.workspace.panelContainers.popover)
workspaceElement.appendChild workspaceElement.panelContainers.popover

atom.workspace.panelContainers.popover.onDidAddPanel ({panel, index}) ->
  schedulePositionPopovers()
  panel.onDidChangeVisible (visible) ->
    schedulePositionPopovers()

atom.workspace.getPopoverPanels = ->
  atom.workspace.getPanels('popover')

atom.workspace.addPopoverPanel = (options) ->
  panel = atom.workspace.addPanel('popover', options)
  options ?= {}
  panel.target = options.target
  panel.viewport = options.viewport
  panel.placement = options.placement or 'top'
  schedulePositionPopovers()
  panel

PanelElement.prototype.positionPopover = ->
  unless target = @model.target
    return

  viewport = @model.viewport or workspaceElement
  placement = @model.placement
  panelRect = @getBoundingClientRect()
  panelRect = # mutable
    top: panelRect.top
    bottom: panelRect.bottom
    left: panelRect.left
    right: panelRect.right
    width: panelRect.width
    height: panelRect.height

  # Target can be a DOM element, a function that returns a rect, or a rect.
  # If they target is dynamic then the popover is continuously positioned in
  # a requestAnimationFrame loop until it's hidden.
  if targetRect = target.getBoundingClientRect?()
    schedulePositionPopovers()
  else if targetRect ?= target?()
    schedulePositionPopovers()
  else
    targetRect = target

  # Target can be a DOM element, a function that returns a rect, or a rect.
  # If they viewport is dynamic then the popover is continuously positioned
  # in a requestAnimationFrame loop until it's hidden.
  if viewportRect = viewport?.getBoundingClientRect?()
    schedulePositionPopovers()
  else if viewportRect ?= viewport?()
    schedulePositionPopovers()
  else
    viewportRect = viewport

  constraintedPlacement = placement

  # Initial positioning and report when out of viewport
  out = @positionPopoverRect panelRect, targetRect, viewportRect, placement

  # Flip placement and reposition panel rect if out of viewport
  if out.top and constraintedPlacement is 'top'
    constraintedPlacement = 'bottom'
  else if out.bottom and constraintedPlacement is 'bottom'
    constraintedPlacement = 'top'
  else if out.left and constraintedPlacement is 'left'
    constraintedPlacement = 'right'
  else if out.right and constraintedPlacement is 'right'
    constraintedPlacement = 'left'

  unless placement is constraintedPlacement
    out = @positionPopoverRect panelRect, targetRect, viewportRect, constraintedPlacement

  # Constrain panel rect to viewport
  if out.top
    panelRect.top = viewportRect.top
  if out.bottom
    panelRect.top = viewportRect.bottom - panelRect.height
  if out.left
    panelRect.left = viewportRect.left
  if out.right
    panelRect.left = viewportRect.right - panelRect.width

  # Update panel top, left style if changed
  unless @cachedTop is panelRect.top and @cachedLeft is panelRect.left
    unless @_arrowDIV
      @_arrowDIV = document.createElement 'div'
      @_arrowDIV.classList.add 'arrow'
      @insertBefore @_arrowDIV, @firstChild

    arrowRect = @_arrowDIV.getBoundingClientRect()

    if constraintedPlacement is 'top' or constraintedPlacement is 'bottom'
      targetX = targetRect.left + (targetRect.width / 2.0)
      left = (targetX - panelRect.left) - (arrowRect.width / 2.0)
      @_arrowDIV.style.left = left + 'px'
    else if constraintedPlacement is 'left' or constraintedPlacement is 'right'
      targetY = targetRect.top + (targetRect.height / 2.0)
      @_arrowDIV.style.top = (targetY - (arrowRect.height / 2.0)) + 'px'

    @setAttribute 'data-arrow', constraintedPlacement
    @style.top = panelRect.top + 'px'
    @style.left = panelRect.left + 'px'
    @cachedTop = panelRect.top
    @cachedLeft = panelRect.left

PanelElement.prototype.positionPopoverRect = (panelRect, targetRect, viewportRect, placement) ->
  switch placement
    when 'top'
      panelRect.top = targetRect.top - panelRect.height
      panelRect.left = targetRect.left - ((panelRect.width - targetRect.width) / 2.0)
    when 'bottom'
      panelRect.top = targetRect.bottom
      panelRect.left = targetRect.left - ((panelRect.width - targetRect.width) / 2.0)
    when 'left'
      panelRect.left = targetRect.left - panelRect.width
      panelRect.top = targetRect.top - ((panelRect.height - targetRect.height) / 2.0)
    when 'right'
      panelRect.left = targetRect.right
      panelRect.top = targetRect.top - ((panelRect.height - targetRect.height) / 2.0)

  panelRect.bottom = panelRect.top + panelRect.height
  panelRect.right = panelRect.left + panelRect.width
  out = {}

  if viewportRect
    if panelRect.top < viewportRect.top
      out['top'] = true
    if panelRect.bottom > viewportRect.bottom
      out['bottom'] = true
    if panelRect.left < viewportRect.left
      out['left'] = true
    if panelRect.right > viewportRect.right
      out['right'] = true

  out

# Popover positioning is performed in a `requestAnimationFrame` loop when
# either of `target` or `viewport` are dynamic (ie functions or elements)
positionPopoversFrameID = null
schedulePositionPopovers = ->
  unless positionPopoversFrameID
    positionPopoversFrameID = window.requestAnimationFrame positionPopovers

positionPopovers = ->
  positionPopoversFrameID = null
  for panel in atom.workspace?.getPopoverPanels()
    if panel.isVisible()
      atom.views.getView(panel).positionPopover()