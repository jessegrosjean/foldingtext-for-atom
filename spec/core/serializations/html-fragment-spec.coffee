ItemSerializer = require '../../../lib/core/item-serializer'
loadOutlineFixture = require '../../load-outline-fixture'
Constants = require '../../../lib/core/constants'
Outline = require '../../../lib/core/outline'

describe 'HTML Fragment Serialization', ->
  [outline, root, one, two, three, four, five, six] = []

  beforeEach ->
    {outline, root, one, two, three, four, five, six} = loadOutlineFixture()
    three.bodyHTMLString = 'thr<b>ee</b>'

  it 'should serialize item as text/html fragment', ->
    ItemSerializer.serializeItems([three], null, Constants.HTMLMimeType).should.equal('thr<b>ee</b>')

  it 'should throw if asked to serialize more then one item', ->
    expect(-> ItemSerializer.serializeItems([one], null, Constants.HTMLMimeType)).toThrow(new Error('Inline-HTML serializer can only serialize a single item.'))
    expect(-> ItemSerializer.serializeItems([three, four], null, Constants.HTMLMimeType)).toThrow(new Error('Inline-HTML serializer can only serialize a single item.'))

  it 'should deserialize items from text/html fragment string', ->
    ItemSerializer.deserializeItems('on<b>e</b>', outline, Constants.HTMLMimeType)[0].bodyHTMLString.should.equal('on<b>e</b>')

  it 'should throw if asked to deserialize plain text with no inline elements', ->
    expect(-> ItemSerializer.deserializeItems('moose', null, Constants.HTMLMimeType)).toThrow(new Error('Inline-HTML deseriaizer must deserialize at least one element.'))