ItemSerializer = require '../../../lib/core/item-serializer'
loadOutlineFixture = require '../../load-outline-fixture'
Outline = require '../../../lib/core/outline'

fixtureAsFTMLString = '''
  <!DOCTYPE html><html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <meta charset="UTF-8" />
    </head>
    <body>
      <ul id="FoldingText">
        <li id="1">
          <p>one</p>
          <ul>
            <li id="2">
              <p>two</p>
              <ul>
                <li id="3" data-t="">
                  <p>three</p>
                </li>
                <li id="4" data-t="">
                  <p>fo<b>u</b>r</p>
                </li>
              </ul>
            </li>
            <li id="5">
              <p>five</p>
              <ul>
                <li id="6" data-t="23">
                  <p>six</p>
                </li>
              </ul>
            </li>
          </ul>
        </li>
      </ul>
    </body>
  </html>
'''

describe 'FTML Serialization', ->
  [outline, root, one, two, three, four, five, six] = []

  beforeEach ->
    {outline, root, one, two, three, four, five, six} = loadOutlineFixture()

  describe 'Serialization', ->
    it 'should serialize items to FTML string', ->
      ItemSerializer.serializeItems(outline.root.children).should.equal(fixtureAsFTMLString)

  describe 'Deserialization', ->
    it 'should load items from FTML string', ->
      one = ItemSerializer.deserializeItems(fixtureAsFTMLString, outline)[0]
      one.bodyString.should.equal('one')
      one.lastChild.bodyString.should.equal('five')
      one.lastChild.lastChild.getAttribute('data-t').should.equal('23')
      one.descendants.length.should.equal(5)

    it 'should throw exception when loading invalid html outline UL child', ->
      ftmlString = '''
        <ul id="FoldingText">
          <div>bad</div>
        </ul>
      '''
      expect(-> ItemSerializer.deserializeItems(ftmlString, outline)).toThrow(new Error("Expected 'LI' or 'UL', but got DIV"))

    it 'should throw exception when loading invalid html outline LI child', ->
      ftmlString = '''
        <ul id="FoldingText">
          <li>bad</li>
        </ul>
      '''
      expect(-> ItemSerializer.deserializeItems(ftmlString, outline)).toThrow(new Error("Expected 'P', but got undefined"))

    it 'should throw exception when loading invalid html outline P contents', ->
      ftmlString = '''
        <ul id="FoldingText">
          <li><p>o<dog>n</dog>e</p></li>
        </ul>
      '''
      expect(-> ItemSerializer.deserializeItems(ftmlString, outline)).toThrow(new Error("Unexpected tagName 'DOG' in 'P'"))