ItemSerializer = require '../core/item-serializer'
Text = require '../core/serializations/text'

serialization =
  priority: 0
  extensions: ['taskpaper']
  mimeTypes: ['com.hogbaysoftware.TaskPaper.document']
  serialization: Text

ItemSerializer.registerSerialization(serialization, true)