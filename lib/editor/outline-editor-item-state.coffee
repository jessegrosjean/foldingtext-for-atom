# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

# If store item editor state inside individual items then stores no
# longer need to manually update associated item sets. Instead they
# just set these flags (keyed by editor ID). In particular, there's
# no longer a need to update those sets when items are added/removed
# from the outline model. Because the state travels with the items.
# This means when you delete a item, and then undo the delete, the state
# should be properly restored.

module.exports =
class OutlineEditorItemState
  constructor: ->
    @marked = false
    @selected = false
    @expanded = false
    @matched = false
    @matchedAncestor = false