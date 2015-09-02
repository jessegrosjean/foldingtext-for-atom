ItemSerializer = require '../../lib/core/item-serializer'
Outline = require '../../lib/core/outline'

describe 'ItemSerializer', ->
  [outline] = []

  beforeEach ->
    outline = new Outline
