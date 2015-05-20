ItemSerializer = require '../../../lib/core/item-serializer'
loadOutlineFixture = require '../../load-outline-fixture'
Constants = require '../../../lib/core/constants'
Outline = require '../../../lib/core/outline'

fixtureAsOPMLString = '''
  <opml version="2.0">
    <head/>
    <body>
      <outline id="1" text="one">
        <outline id="2" text="two">
          <outline id="3" text="three" t=""/>
          <outline id="4" text="fo&lt;b&gt;u&lt;/b&gt;r" t=""/>
        </outline>
        <outline id="5" text="five" created="Wed, 20 May 2015 14:04:27 GMT">
          <outline id="6" text="six" t="23"/>
        </outline>
      </outline>
    </body>
  </opml>
'''

describe 'OPML Serialization', ->
  [outline, root, one, two, three, four, five, six] = []

  beforeEach ->
    {outline, root, one, two, three, four, five, six} = loadOutlineFixture()
    five.setAttribute('data-created', new Date('2015-05-20T14:04:27.000Z'))

  it 'should serialize items to OPML string', ->
    ItemSerializer.serializeItems(outline.root.children, null, Constants.OPMLMimeType).should.equal(fixtureAsOPMLString)

  it 'should deserialize items from OPML string', ->
    one = ItemSerializer.deserializeItems(fixtureAsOPMLString, outline, Constants.OPMLMimeType)[0]
    one.bodyText.should.equal('one')
    one.lastChild.bodyText.should.equal('five')
    one.lastChild.lastChild.getAttribute('data-t').should.equal('23')
    one.descendants.length.should.equal(5)
