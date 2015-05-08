loadOutlineFixture = require '../load-outline-fixture'
Constants = require '../../lib/core/constants'
Outline = require '../../lib/core/outline'
Item = require '../../lib/core/item'

describe 'Item', ->
  [outline, root, one, two, three, four, five, six] = []

  beforeEach ->
    {outline, root, one, two, three, four, five, six} = loadOutlineFixture()

  it 'should get parent', ->
    two.parent.should.equal(one)
    one.parent.should.equal(root)

  it 'should append item', ->
    item = outline.createItem('hello')
    outline.root.appendChild(item)
    item.parent.should.equal(outline.root)
    item.isInOutline.should.be.true

  it 'should delete item', ->
    two.removeFromParent()
    expect(two.parent is undefined).toBe(true)

  it 'should make item connections', ->
    one.firstChild.should.equal(two)
    one.lastChild.should.equal(five)
    one.firstChild.nextSibling.should.equal(five)
    one.lastChild.previousSibling.should.equal(two)

  it 'should calculate cover items', ->
    Item.getCommonAncestors([
      three,
      five,
      six,
    ]).should.eql([three, five])

  describe 'Attributes', ->
    it 'should set/get attribute', ->
      expect(five.getAttribute('test') is null).toBe(true)
      five.setAttribute('test', 'hello')
      five.getAttribute('test').should.equal('hello')

    it 'should get/set attribute as array', ->
      five.setAttribute('test', ['one', 'two', 'three'])
      five.getAttribute('test').should.equal('one,two,three')
      five.getAttribute('test', true).should.eql(['one', 'two', 'three'])

    it 'should get/set number attributes', ->
      five.setAttribute('test', [1, 2, 3])
      five.getAttribute('test').should.equal('1,2,3')
      five.getAttribute('test', true).should.eql(['1', '2', '3'])
      five.getAttribute('test', true, Number).should.eql([1, 2, 3])

    it 'should get/set date attributes', ->
      date = new Date('11/27/76')
      five.setAttribute('test', [date, date], Date)
      five.getAttribute('test').should.equal('1976-11-27T05:00:00.000Z,1976-11-27T05:00:00.000Z')
      five.getAttribute('test', true).should.eql(['1976-11-27T05:00:00.000Z', '1976-11-27T05:00:00.000Z'])
      five.getAttribute('test', true, Date).should.eql([date, date])

  describe 'Body', ->
    it 'should get', ->
      one.bodyText.should.equal('one')
      one.bodyHTML.should.equal('one')
      one.bodyText.length.should.equal(3)

    it 'should get empy', ->
      item = outline.createItem('')
      item.bodyText.should.equal('')
      item.bodyHTML.should.equal('')
      item.bodyText.length.should.equal(0)

    it 'should get/set by Text', ->
      one.bodyText = 'one <b>two</b> three'
      one.bodyText.should.equal('one <b>two</b> three')
      one.bodyHTML.should.equal('one &lt;b&gt;two&lt;/b&gt; three')
      one.bodyText.length.should.equal(20)

    it 'should get/set by HTML', ->
      one.bodyHTML = 'one <b>two</b> three'
      one.bodyText.should.equal('one two three')
      one.bodyHTML.should.equal('one <b>two</b> three')
      one.bodyText.length.should.equal(13)

    describe 'Inline Elements', ->
      it 'should get elements', ->
        one.bodyHTML = '<b>one</b> <img src="boo.png">two three'
        one.getElementsAtBodyTextIndex(0).should.eql({ B: null })
        one.getElementsAtBodyTextIndex(4).should.eql({ IMG: { src: 'boo.png' } })

      it 'should get empty elements', ->
        one.bodyText = 'one two three'
        one.getElementsAtBodyTextIndex(0).should.eql({})

      it 'should add elements', ->
        one.bodyText = 'one two three'
        one.addElementInBodyTextRange('B', null, 4, 3)
        one.bodyHTML.should.equal('one <b>two</b> three')

      it 'should add overlapping back element', ->
        one.bodyText = 'one two three'
        one.addElementInBodyTextRange('B', null, 0, 7)
        one.addElementInBodyTextRange('I', null, 4, 9)
        one.bodyHTML.should.equal('<b>one <i>two</i></b><i> three</i>')

      it 'should add overlapping front and back element', ->
        one.bodyText = 'three'
        one.addElementInBodyTextRange('B', null, 0, 2)
        one.addElementInBodyTextRange('U', null, 1, 3)
        one.addElementInBodyTextRange('I', null, 3, 2)
        one.bodyHTML.should.equal('<b>t<u>h</u></b><u>r<i>e</i></u><i>e</i>')

      it 'should add append text with elements', ->
        one.bodyText = ''
        one.appendBodyText('o', {'I': {}})
        one.appendBodyText('ne', {'I': {}, 'B': {}})
        one.bodyHTML.should.equal('<i>o<b>ne</b></i>')

      it 'should add consecutive attribute with different values', ->
        one.addElementInBodyTextRange('SPAN', 'data-a': 'a', 0, 1)
        one.addElementInBodyTextRange('SPAN', 'data-b': 'b', 1, 2)
        one.bodyHTML.should.equal('<span data-a="a">o</span><span data-b="b">ne</span>')

      it 'should add consecutive attribute with same values', ->
        one.addElementInBodyTextRange('SPAN', 'data-a': 'a', 0, 1)
        one.addElementInBodyTextRange('SPAN', 'data-a': 'a', 1, 2)
        one.bodyHTML.should.equal('<span data-a="a">one</span>')

      it 'should remove element', ->
        one.bodyHTML = '<b>one</b>'
        one.removeElementInBodyTextRange('B', 0, 3)
        one.bodyHTML.should.equal('one')

      it 'should remove middle of element span', ->
        one.bodyHTML = '<b>one</b>'
        one.removeElementInBodyTextRange('B', 1, 1)
        one.bodyHTML.should.equal('<b>o</b>n<b>e</b>')

      describe 'Void Elements', ->
        it 'should remove tags when they become empty if they are not void tags', ->
          one.bodyHTML = 'one <b>two</b> three'
          one.replaceBodyTextInRange('', 4, 3)
          one.bodyText.should.equal('one  three')
          one.bodyHTML.should.equal('one  three')

        it 'should not remove void tags that are empty', ->
          one.bodyHTML = 'one <br><img> three'
          one.bodyText.length.should.equal(12)
          one.bodyHTML.should.equal('one <br><img> three')

        it 'void tags should count as length 1 in outline range', ->
          one.bodyHTML = 'one <br><img> three'
          one.replaceBodyTextInRange('', 7, 3)
          one.bodyHTML.should.equal('one <br><img> ee')

        it 'void tags should be replaceable', ->
          one.bodyHTML = 'one <br><img> three'
          one.replaceBodyTextInRange('', 4, 1)
          one.bodyHTML.should.equal('one <img> three')
          one.bodyText.length.should.equal(11)

        xit 'text content enocde <br> using "New Line Character"', ->
          one.bodyText = 'one \u2028 three'
          one.bodyHTML.should.equal('one <br> three')
          one.bodyText.should.equal('one \u2028 three')
          one.bodyText(4, 1).should.equal(Constants.LineSeparatorCharacter)

        it 'text content encode <img> and other void tags using "Object Replacement Character"', ->
          one.bodyHTML = 'one <img> three'
          one.bodyText.should.equal('one \ufffc three')