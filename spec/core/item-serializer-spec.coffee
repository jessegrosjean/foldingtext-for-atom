ItemSerializer = require '../../lib/core/item-serializer'
Outline = require '../../lib/core/outline'

describe 'ItemSerializer', ->
  [outline] = []

  beforeEach ->
    outline = new Outline

  describe 'Items From HTML', ->
    it 'should load items from html outline', ->
      htmlOutline = '''
        <ul id="FoldingText">
          <li><p>one</p></li>
          <li><p>two</p></li>
          <li><p>three</p></li>
        </ul>
      '''
      items = ItemSerializer.itemsFromHTML(htmlOutline, outline)
      expect(items.itemFragmentString).toBeUndefined()
      items.length.should.equal(3)

    it 'should report error when loading invalid html outline UL child', ->
      htmlOutline = '''
        <ul id="FoldingText">
          <div>bad</div>
        </ul>
      '''
      expect(-> ItemSerializer.itemsFromHTML(htmlOutline, outline)).toThrow(new Error("Expected 'LI' or 'UL', but got DIV"))

    it 'should report error when loading invalid html outline LI child', ->
      htmlOutline = '''
        <ul id="FoldingText">
          <li>bad</li>
        </ul>
      '''
      expect(-> ItemSerializer.itemsFromHTML(htmlOutline, outline)).toThrow(new Error("Expected 'P', but got undefined"))

    it 'should report error when loading invalid html outline P contents', ->
      htmlOutline = '''
        <ul id="FoldingText">
          <li><p>o<dog>n</dog>e</p></li>
        </ul>
      '''
      expect(-> ItemSerializer.itemsFromHTML(htmlOutline, outline)).toThrow(new Error("Unexpected tagName 'DOG' in 'P'"))

    it 'should load non html outline into fragment string', ->
      items = ItemSerializer.itemsFromHTML('one <b>two</b> three', outline)
      items.itemFragmentString.toString().should.equal('(one /)(two/B)( three/)')
      items.length.should.equal(0)

    it 'should load non html outline into fragment string stripping invalid tags', ->
      items = ItemSerializer.itemsFromHTML('one <dog>two</dog> three', outline)
      items.itemFragmentString.toString().should.equal('(one two three/)')
      items.length.should.equal(0)

    it 'should throw when expecting html outline and not finding one', ->
      expect(-> ItemSerializer.itemsFromHTML('one <dog>two</dog> three', outline, true)).toThrow(new Error('Could not find <ul id="FoldingText"> element.'))

itemsFromHTML = (htmlString, outline, editor) ->
