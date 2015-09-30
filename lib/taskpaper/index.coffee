SyncRules = require './sync-rules'
require './serialization'
require './commands'

module.exports =
  initOutline: (outline) ->
    outline.registerAttributeBodySyncRule(SyncRules)