ItemSerializer = require '../../../lib/core/item-serializer'
loadOutlineFixture = require '../../load-outline-fixture'
Constants = require '../../../lib/core/constants'
Outline = require '../../../lib/core/outline'

fixtureAsTextString = '''
  one
  \ttwo
  \t\tthree @t
  \t\tfour @t
  \tfive
  \t\tsix @t(23)
'''

describe 'TEXT Serialization', ->
  [outline, root, one, two, three, four, five, six] = []

  beforeEach ->
    {outline, root, one, two, three, four, five, six} = loadOutlineFixture()

  it 'should serialize items to TEXT string', ->
    ItemSerializer.serializeItems(outline.root.children, null, Constants.TEXTMimeType).should.equal(fixtureAsTextString)

  it 'should deserialize items from TEXT string', ->
    one = ItemSerializer.deserializeItems(fixtureAsTextString, outline, Constants.TEXTMimeType)[0]
    one.bodyString.should.equal('one')
    one.descendants.length.should.equal(5)
    three.hasAttribute('data-t').should.be.true
    four.hasAttribute('data-t').should.be.true
    five.bodyString.should.equal('five')
    six.getAttribute('data-t').should.equal('23')