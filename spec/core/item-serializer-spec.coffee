ItemSerializer = require '../../lib/core/item-serializer'
Outline = require '../../lib/core/outline'

describe 'ItemSerializer', ->
  [outline] = []

  beforeEach ->
    outline = new Outline

  describe 'Items From HTML', ->
    it 'should load non html outline into fragment string', ->
      items = ItemSerializer.itemsFromHTML('one <b>two</b> three', outline)
      items.itemFragmentString.toString().should.equal('(one /)(two/B)( three/)')
      items.length.should.equal(0)

itemsFromHTML = (htmlString, outline, editor) ->
