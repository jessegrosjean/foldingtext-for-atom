ItemPath = require '../core/item-path'
SyncRules = require './sync-rules'
require './serialization'
require './commands'

ItemPath.defaultTypes = 'project': true, 'task': true, 'note': true

module.exports =
  initOutline: (outline) ->
    outline.registerAttributeBodySyncRule(SyncRules)