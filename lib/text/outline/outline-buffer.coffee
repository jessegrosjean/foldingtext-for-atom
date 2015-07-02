{repeat, replace, leadingTabs} = require './helpers'
{Emitter, CompositeDisposable} = require 'atom'
Buffer = require './Buffer'
Range = require './Range'

class OutlineBuffer extends Buffer

  hoistedItem: null

  constructor: (outline) ->
    super()
    @emitter = new Emitter()
    @subscriptions = new CompositeDisposable
    @outline = outline or Outline.buildOutlineSync()
    @subscribeToOutline()

  subscribeToOutline: ->
    @outline.retain()
    @subscriptions.add @outline.onDidChange @outlineDidChange.bind(this)
    @subscriptions.add @outline.onDidDestroy => @destroy()

  outlineDidChange: (mutations) ->
    for eachMutation in mutations
      if eachMutation.type is Mutation.CHILDREN_CHANGED
        targetItem = eachMutation.target

  destroy: ->
    unless @destroyed
      @destroyed = true
      @subscriptions.dispose()
      @outline.release
      @emitter.emit 'did-destroy'

  ###
  Section: Text Overrides
  ###

  getLineText: (line) ->
    item = line.data
    bodyText = item.bodyText
    tabCount = item.depth - @hoistedItem.depth
    tabs = repeat('\t', tabCount)
    tabs + bodyText

  replaceLineTextInRange: (line, start, length, text) ->
    # Update Item state based on text change. Need to calcuate item body text
    # range to replace and items new indent level.
    oldText = @getLineText(line)
    oldLeadingTabs = leadingTabs(oldText)
    newText = replace(oldText, start, length, text)
    newLeadingTabs = leadingTabs(newText)
    depthDelta = newLeadingTabs - oldLeadingTabs

    item = line.data
    outline = item.outline
    outline.beginUpdates()


    if start <= oldLeadingTabs
      start = oldLeadingTabs

    # Replace item body text if changed
    item.replaceBodyTextInRange(insertedText, start, length)

    # Reinsert item if depth changed
    if depthDelta
      depth = item.depth
      referenceItem = item.nextItem
      outline.removeItem(item)
      outline.insertItemAtDepthBefore(item, depth + depthDelta, referenceItem)

    line.setCharacterCount(newText.length)
    outline.endUpdates()

  createLineFromText: (text) ->
    level = leadingTabs(text)
    text = text.substr(level)
    item = @outline.createItem(text)
    item.indent = leadingTabs
    new Line(item, text.length)

module.exports = OutlineBuffer