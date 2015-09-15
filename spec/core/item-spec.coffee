loadOutlineFixture = require '../load-outline-fixture'
Constants = require '../../lib/core/constants'
Outline = require '../../lib/core/outline'
Item = require '../../lib/core/item'
should = require 'should'

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
    expect(two.parent is null).toBe(true)

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

  it 'should build item hiearchy', ->
    a = outline.createItem('a')
    a.indent = 1
    b = outline.createItem('b')
    b.indent = 2

    stack = [a]
    Item.buildItemHiearchy([b], stack)
    b.parent.should.equal(a)
    a.depth.should.equal(1)
    b.depth.should.equal(2)

  describe 'Attributes', ->
    it 'should set/get attribute', ->
      expect(five.getAttribute('test') is undefined).toBe(true)
      five.setAttribute('test', 'hello')
      five.getAttribute('test').should.equal('hello')

    it 'should get/set attribute as array', ->
      five.setAttribute('test', 'one,two,three')
      five.getAttribute('test', true).should.eql(['one', 'two', 'three'])

    it 'should get/set number attributes', ->
      five.setAttribute('test', '1,2,3')
      five.getAttribute('test', true).should.eql(['1', '2', '3'])
      five.getAttribute('test', true, Number).should.eql([1, 2, 3])

    it 'should get/set date attributes', ->
      date = new Date('11/27/76')
      dateString = date.toISOString()
      five.setAttribute('test', "#{dateString},#{dateString}")
      five.getAttribute('test', true).should.eql([dateString, dateString])
      five.getAttribute('test', true, Date).should.eql([date, date])

  describe 'Body', ->
    it 'should get', ->
      one.bodyString.should.equal('one')
      one.bodyHTMLString.should.equal('one')
      one.bodyString.length.should.equal(3)

    it 'should get empy', ->
      item = outline.createItem('')
      item.bodyString.should.equal('')
      item.bodyHTMLString.should.equal('')
      item.bodyString.length.should.equal(0)

    it 'should get/set by Text', ->
      one.bodyString = 'one <b>two</b> three'
      one.bodyString.should.equal('one <b>two</b> three')
      one.bodyHTMLString.should.equal('one &lt;b&gt;two&lt;/b&gt; three')
      one.bodyString.length.should.equal(20)

    it 'should get/set by HTML', ->
      one.bodyHTMLString = 'one <b>two</b> three'
      one.bodyString.should.equal('one two three')
      one.bodyHTMLString.should.equal('one <b>two</b> three')
      one.bodyString.length.should.equal(13)

    describe 'Inline Elements', ->
      it 'should get elements', ->
        one.bodyHTMLString = '<b>one</b> <img src="boo.png">two three'
        one.getBodyAttributesAtIndex(0).should.eql({ B: null })
        one.getBodyAttributesAtIndex(3).should.eql({})
        one.getBodyAttributesAtIndex(4).should.eql({ IMG: { src: 'boo.png' } })

      it 'should get empty elements', ->
        one.bodyString = 'one two three'
        one.getBodyAttributesAtIndex(0).should.eql({})

      it 'should add elements', ->
        one.bodyString = 'one two three'
        one.addBodyAttributeInRange('B', null, 4, 3)
        one.bodyHTMLString.should.equal('one <b>two</b> three')

      it 'should add overlapping back element', ->
        one.bodyString = 'one two three'
        one.addBodyAttributeInRange('B', null, 0, 7)
        one.addBodyAttributeInRange('I', null, 4, 9)
        one.bodyHTMLString.should.equal('<b>one <i>two</i></b><i> three</i>')

      it 'should add overlapping front and back element', ->
        one.bodyString = 'three'
        one.addBodyAttributeInRange('B', null, 0, 2)
        one.addBodyAttributeInRange('U', null, 1, 3)
        one.addBodyAttributeInRange('I', null, 3, 2)
        one.bodyHTMLString.should.equal('<b>t<u>h</u></b><u>r<i>e</i></u><i>e</i>')

      it 'should add append text with elements', ->
        one.bodyString = ''
        one.appendBody('o', {'I': {}})
        one.appendBody('ne', {'I': {}, 'B': {}})
        one.bodyHTMLString.should.equal('<i>o<b>ne</b></i>')

      it 'should add consecutive attribute with different values', ->
        one.addBodyAttributeInRange('SPAN', 'data-a': 'a', 0, 1)
        one.addBodyAttributeInRange('SPAN', 'data-b': 'b', 1, 2)
        one.bodyHTMLString.should.equal('<span data-a="a">o</span><span data-b="b">ne</span>')

      it 'should add consecutive attribute with same values', ->
        one.addBodyAttributeInRange('SPAN', 'data-a': 'a', 0, 1)
        one.addBodyAttributeInRange('SPAN', 'data-a': 'a', 1, 2)
        one.bodyHTMLString.should.equal('<span data-a="a">one</span>')

      it 'should remove element', ->
        one.bodyHTMLString = '<b>one</b>'
        one.removeBodyAttributeInRange('B', 0, 3)
        one.bodyHTMLString.should.equal('one')

      it 'should remove middle of element span', ->
        one.bodyHTMLString = '<b>one</b>'
        one.removeBodyAttributeInRange('B', 1, 1)
        one.bodyHTMLString.should.equal('<b>o</b>n<b>e</b>')

      describe 'Void Elements', ->
        it 'should remove tags when they become empty if they are not void tags', ->
          one.bodyHTMLString = 'one <b>two</b> three'
          one.replaceBodyRange(4, 3, '')
          one.bodyString.should.equal('one  three')
          one.bodyHTMLString.should.equal('one  three')

        it 'should not remove void tags that are empty', ->
          one.bodyHTMLString = 'one <br><img> three'
          one.bodyString.length.should.equal(12)
          one.bodyHTMLString.should.equal('one <br><img> three')

        it 'void tags should count as length 1 in outline range', ->
          one.bodyHTMLString = 'one <br><img> three'
          one.replaceBodyRange(7, 3, '')
          one.bodyHTMLString.should.equal('one <br><img> ee')

        it 'void tags should be replaceable', ->
          one.bodyHTMLString = 'one <br><img> three'
          one.replaceBodyRange(4, 1, '')
          one.bodyHTMLString.should.equal('one <img> three')
          one.bodyString.length.should.equal(11)

        it 'text content enocde <br> using "New Line Character"', ->
          one.bodyHTMLString = 'one <br> three'
          one.bodyString.should.equal("one #{Constants.LineSeparatorCharacter} three")

        it 'text content encode <img> and other void tags using "Object Replacement Character"', ->
          one.bodyHTMLString = 'one <img> three'
          one.bodyString.should.equal("one #{Constants.ObjectReplacementCharacter} three")