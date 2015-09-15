ItemSerializer = require '../../../lib/core/item-serializer'
loadOutlineFixture = require '../../load-outline-fixture'
Constants = require '../../../lib/core/constants'
Outline = require '../../../lib/core/outline'

fixtureAsURIListString = '''
# one
?selection=1%2Cundefined%2C1%2Cundefined
'''

describe 'uri-list Serialization', ->
  [outline, root, one, two, three, four, five, six] = []

  beforeEach ->
    {outline, root, one, two, three, four, five, six} = loadOutlineFixture()

  it 'should serialize items to uri-list string', ->
    ItemSerializer.serializeItems(outline.root.children, null, Constants.URIListMimeType).should.equal(fixtureAsURIListString)

  it 'should deserialize items from uri-list string', ->
    one = ItemSerializer.deserializeItems(fixtureAsURIListString, outline, Constants.URIListMimeType)[0]
    one.bodyString.should.equal('one')
    one.bodyHTMLString.should.equal('<a href="?selection=1%2Cundefined%2C1%2Cundefined">one</a>')
    one.descendants.length.should.equal(0)
