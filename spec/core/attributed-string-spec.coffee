AttributedString = require '../../lib/core/attributed-string-ftml'

describe 'AttributedString', ->
  [attributedString] = []

  beforeEach ->
    attributedString = new AttributedString 'Hello world!'

  describe 'Get Substrings', ->

    it 'should get string', ->
      attributedString.getString().should.equal('Hello world!')

    it 'should get substring', ->
      attributedString.substr(0, 5).should.equal('Hello')
      attributedString.substr(6, 6).should.equal('world!')

    it 'should get attributed substring from start', ->
      substring = attributedString.subattributedString(0, 5)
      substring.toString().should.equal('lines: (Hello) runs: (Hello)')

    it 'should get attributed substring from end', ->
      substring = attributedString.subattributedString(6, 6)
      substring.toString().should.equal('lines: (world!) runs: (world!)')

    it 'should get empty attributed substring', ->
      attributedString.subattributedString(1, 0).toString().should.equal('lines:  runs: ')

    it 'should get attributed substring with attributes', ->
      attributedString.addAttributeInRange('name', 'jesse', 0, 5)

      substring = attributedString.subattributedString(0, 12)
      substring.toString().should.equal(attributedString.toString())

      substring = attributedString.subattributedString(0, 5)
      substring.toString().should.equal('lines: (Hello) runs: (Hello/name:"jesse")')

    it 'should get attributed substring with overlapping attributes', ->
      attributedString.addAttributeInRange('i', null, 0, 12)
      attributedString.addAttributeInRange('b', null, 4, 3)
      attributedString.toString().should.equal('lines: (Hello world!) runs: (Hell/i:null)(o w/b:null/i:null)(orld!/i:null)')
      substring = attributedString.subattributedString(6, 6)
      substring.toString().should.equal('lines: (world!) runs: (w/b:null/i:null)(orld!/i:null)')

  describe 'Delete Characters', ->

    it 'should delete from start', ->
      attributedString.deleteRange(0, 6)
      attributedString.toString().should.equal('lines: (world!) runs: (world!)')

    it 'should delete from end', ->
      attributedString.deleteRange(5, 7)
      attributedString.toString().should.equal('lines: (Hello) runs: (Hello)')

    it 'should delete from middle', ->
      attributedString.deleteRange(3, 5)
      attributedString.toString().should.equal('lines: (Helrld!) runs: (Helrld!)')

    it 'should adjust attribute run when deleting from start', ->
      attributedString.addAttributeInRange('b', null, 0, 5)
      attributedString.deleteRange(0, 1)
      attributedString.toString().should.equal('lines: (ello world!) runs: (ello/b:null)( world!)')

    it 'should adjust attribute run when deleting from end', ->
      attributedString.addAttributeInRange('b', null, 0, 5)
      attributedString.deleteRange(3, 2)
      attributedString.toString().should.equal('lines: (Hel world!) runs: (Hel/b:null)( world!)')

    it 'should adjust attribute run when deleting from middle', ->
      attributedString.addAttributeInRange('b', null, 0, 5)
      attributedString.deleteRange(2, 2)
      attributedString.toString().should.equal('lines: (Heo world!) runs: (Heo/b:null)( world!)')

    it 'should adjust attribute run when overlapping start', ->
      attributedString.addAttributeInRange('b', null, 6, 6)
      attributedString.deleteRange(5, 2)
      attributedString.toString().should.equal('lines: (Helloorld!) runs: (Hello)(orld!/b:null)')

    it 'should adjust attribute run when overlapping end', ->
      attributedString.addAttributeInRange('b', null, 0, 5)
      attributedString.deleteRange(4, 2)
      attributedString.toString().should.equal('lines: (Hellworld!) runs: (Hell/b:null)(world!)')

    it 'should remove attribute run when covering from start', ->
      attributedString.addAttributeInRange('b', null, 0, 5)
      attributedString.deleteRange(0, 6)
      attributedString.toString().should.equal('lines: (world!) runs: (world!)')

    it 'should remove attribute run when covering from end', ->
      attributedString.addAttributeInRange('b', null, 6, 6)
      attributedString.deleteRange(5, 7)
      attributedString.toString().should.equal('lines: (Hello) runs: (Hello)')

  describe 'Insert String', ->

    it 'should insert at start', ->
      attributedString.insertText(0, 'Boo!')
      attributedString.toString().should.equal('lines: (Boo!Hello world!) runs: (Boo!Hello world!)')

    it 'should insert at end', ->
      attributedString.insertText(12, 'Boo!')
      attributedString.toString().should.equal('lines: (Hello world!Boo!) runs: (Hello world!Boo!)')

    it 'should insert in middle', ->
      attributedString.insertText(6, 'Boo!')
      attributedString.toString().should.equal('lines: (Hello Boo!world!) runs: (Hello Boo!world!)')

    it 'should insert into empty string', ->
      attributedString.deleteRange(0, 12)
      attributedString.insertText(0, 'Boo!')
      attributedString.toString().should.equal('lines: (Boo!) runs: (Boo!)')

    it 'should adjust attribute run when inserting at run start', ->
      attributedString.addAttributeInRange('b', null, 0, 5)
      attributedString.insertText(0, 'Boo!')
      attributedString.toString().should.equal('lines: (Boo!Hello world!) runs: (Boo!Hello/b:null)( world!)')

    it 'should adjust attribute run when inserting at run end', ->
      attributedString.addAttributeInRange('b', null, 0, 5)
      attributedString.insertText(5, 'Boo!')
      attributedString.toString().should.equal('lines: (HelloBoo! world!) runs: (HelloBoo!/b:null)( world!)')

    it 'should adjust attribute run when inserting in run middle', ->
      attributedString.addAttributeInRange('b', null, 0, 5)
      attributedString.insertText(3, 'Boo!')
      attributedString.toString().should.equal('lines: (HelBoo!lo world!) runs: (HelBoo!lo/b:null)( world!)')

    it 'should insert attributed string including runs', ->
      insert = new AttributedString('Boo!')
      insert.addAttributeInRange('i', null, 0, 3)
      insert.addAttributeInRange('b', null, 1, 3)
      attributedString.insertText(0, insert)
      attributedString.toString().should.equal('lines: (Boo!Hello world!) runs: (B/i:null)(oo/b:null/i:null)(!/b:null)(Hello world!)')

  describe 'Replace Substrings', ->

    it 'should update attribute runs when attributed string is modified', ->
      attributedString.addAttributeInRange('name', 'jesse', 0, 12)
      attributedString.replaceRangeWithText(0, 12, 'Hello')
      attributedString.toString().should.equal('lines: (Hello) runs: (Hello/name:"jesse")')
      attributedString.replaceRangeWithText(5, 0, ' World!')
      attributedString.toString().should.equal('lines: (Hello World!) runs: (Hello World!/name:"jesse")')

    it 'should update attribute runs when node text is paritially updated', ->
      attributedString.addAttributeInRange('name', 'jesse', 0, 5)
      attributedString.addAttributeInRange('name', 'joe', 5, 7)
      attributedString.toString(true).should.equal('lines: (Hello world!) runs: (Hello/name:"jesse")( world!/name:"joe")')

      attributedString.replaceRangeWithText(3, 5, '')
      attributedString.toString(true).should.equal('lines: (Helrld!) runs: (Hel/name:"jesse")(rld!/name:"joe")')

      attributedString.replaceRangeWithText(3, 0, 'lo wo')
      attributedString.toString(true).should.equal('lines: (Hello world!) runs: (Hello wo/name:"jesse")(rld!/name:"joe")')

    it 'should remove leading attribute run if text in run is fully replaced', ->
      attributedString = new AttributedString('\ttwo')
      attributedString.addAttributeInRange('name', 'jesse', 0, 1)
      attributedString.replaceRangeWithText(0, 1, '')
      attributedString.toString().should.equal('lines: (two) runs: (two)')

    it 'should retain attributes of fully replaced range if replacing string length is not zero.', ->
      attributedString = new AttributedString('\ttwo')
      attributedString.addAttributeInRange('name', 'jesse', 0, 1)
      attributedString.replaceRangeWithText(0, 1, 'h')
      attributedString.toString().should.equal('lines: (htwo) runs: (h/name:"jesse")(two)')

    it 'should allow inserting of another attributed string', ->
      newString = new AttributedString('two')
      newString.addAttributeInRange('b', null, 0, 3)

      attributedString.addAttributeInRange('i', null, 0, 12)
      attributedString.replaceRangeWithText(5, 1, newString)
      attributedString.toString().should.equal('lines: (Hellotwoworld!) runs: (Hello/i:null)(two/b:null)(world!/i:null)')

  describe 'Add/Remove/Find Attributes', ->

    it 'should add attribute run', ->
      range = {}
      attributedString.addAttributeInRange('name', 'jesse', 0, 5)
      attributedString.getAttributesAtIndex(0, range).name.should.equal('jesse')
      range.location.should.equal(0)
      range.length.should.equal(5)
      attributedString.getAttributesAtIndex(5, range).should.eql({})
      range.location.should.equal(5)
      range.length.should.equal(7)

    it 'should add attribute run bordering start of string', ->
      range = {}
      attributedString.addAttributeInRange('name', 'jesse', 0, 5)
      attributedString.getAttributesAtIndex(0, range).name.should.equal('jesse')
      range.location.should.equal(0)
      range.length.should.equal(5)

    it 'should add attribute run bordering end of string', ->
      range = {}
      attributedString.addAttributeInRange('name', 'jesse', 6, 6)
      attributedString.getAttributesAtIndex(6, range).name.should.equal('jesse')
      range.location.should.equal(6)
      range.length.should.equal(6)

    it 'should find longest effective range for attribute', ->
      longestEffectiveRange = {}
      attributedString.addAttributeInRange('one', 'one', 0, 12)
      attributedString.addAttributeInRange('two', 'two', 6, 6)
      attributedString.getAttributeAtIndex('one', 6, null, longestEffectiveRange).should.equal('one')
      longestEffectiveRange.should.eql(location: 0, length: 12)

    it 'should add multiple attributes in same attribute run', ->
      range = {}
      attributedString.addAttributeInRange('name', 'jesse', 0, 5)
      attributedString.addAttributeInRange('age', '35', 0, 5)
      attributedString.getAttributesAtIndex(0, range).name.should.equal('jesse')
      attributedString.getAttributesAtIndex(0, range).age.should.equal('35')
      range.location.should.equal(0)
      range.length.should.equal(5)

    it 'should add attributes in overlapping ranges', ->
      range = {}
      attributedString.addAttributeInRange('name', 'jesse', 0, 5)
      attributedString.addAttributeInRange('age', '35', 3, 5)

      attributedString.getAttributesAtIndex(0, range).name.should.equal('jesse')
      (attributedString.getAttributesAtIndex(0, range).age is undefined).should.be.true
      range.location.should.equal(0)
      range.length.should.equal(3)

      attributedString.getAttributesAtIndex(3, range).name.should.equal('jesse')
      attributedString.getAttributesAtIndex(3, range).age.should.equal('35')
      range.location.should.equal(3)
      range.length.should.equal(2)

      (attributedString.getAttributesAtIndex(6, range).name is undefined).should.be.true
      attributedString.getAttributesAtIndex(6, range).age.should.equal('35')
      range.location.should.equal(5)
      range.length.should.equal(3)

    it 'should allow removing attributes in range', ->
      attributedString.addAttributeInRange('name', 'jesse', 0, 12)
      attributedString.removeAttributeInRange('name', 0, 12)
      attributedString.toString(true).should.equal('lines: (Hello world!) runs: (Hello world!)')

      attributedString.addAttributeInRange('name', 'jesse', 0, 12)
      attributedString.removeAttributeInRange('name', 0, 3)
      attributedString.toString(true).should.equal('lines: (Hello world!) runs: (Hel)(lo world!/name:"jesse")')

      attributedString.removeAttributeInRange('name', 9, 3)
      attributedString.toString(true).should.equal('lines: (Hello world!) runs: (Hel)(lo wor/name:"jesse")(ld!)')

    it 'should throw when accessing attributes past end of string', ->
      (-> attributedString.getAttributesAtIndex(11)).should.not.throw()
      (-> attributedString.getAttributesAtIndex(12)).should.throw()
      attributedString.replaceRangeWithText(0, 12, '')
      (-> attributedString.getAttributesAtIndex(0)).should.throw()

  describe 'Inline FTML', ->

    beforeEach ->
      attributedString = new AttributedString 'Hello world!'

    describe 'To Inline FTML', ->

      it 'should convert to Inline FTML', ->
        attributedString.toInlineFTMLString().should.equal('Hello world!')

      it 'should convert to Inline FTML with attributes', ->
        attributedString.addAttributeInRange('B', 'data-my': 'test', 3, 5)
        attributedString.toInlineFTMLString().should.equal('Hel<b data-my="test">lo wo</b>rld!')

      it 'should convert empty to Inline FTML', ->
        new AttributedString().toInlineFTMLString().should.equal('')

    describe 'From Inline FTML', ->

      it 'should convert from Inline FTML', ->
        AttributedString.fromInlineFTMLString('Hello world!').toString().should.equal('lines: (Hello world!) runs: (Hello world!)')

      it 'should convert from Inline FTML with attributes', ->
        AttributedString.fromInlineFTMLString('Hel<b data-my="test">lo wo</b>rld!').toString().should.equal('lines: (Hello world!) runs: (Hel)(lo wo/B:{"data-my":"test"})(rld!)')

      it 'should convert from empty Inline FTML', ->
        AttributedString.fromInlineFTMLString('').toString().should.equal('lines:  runs: ')

    describe 'Offset Mapping', ->

      it 'should map from string to Inline FTML locations', ->
        attributedString = AttributedString.fromInlineFTMLString('Hel<b data-my="test">lo wo</b>rld!')
        inlineFTMLContainer = attributedString.toInlineFTMLFragment()

        AttributedString.textIndexToInlineFTMLIndex(0, inlineFTMLContainer).should.eql
          node: inlineFTMLContainer.firstChild
          index: 0

        AttributedString.textIndexToInlineFTMLIndex(3, inlineFTMLContainer).should.eql
          node: inlineFTMLContainer.firstChild
          index: 3

        AttributedString.textIndexToInlineFTMLIndex(4, inlineFTMLContainer).should.eql
          node: inlineFTMLContainer.firstChild.nextSibling.firstChild
          index: 1

        AttributedString.textIndexToInlineFTMLIndex(12, inlineFTMLContainer).should.eql
          node: inlineFTMLContainer.firstChild.nextSibling.nextSibling
          index: 4

      it 'should map from string to empty Inline FTML locations', ->
        inlineFTMLContainer = document.createElement 'p'
        AttributedString.textIndexToInlineFTMLIndex(0, inlineFTMLContainer).should.eql
          node: inlineFTMLContainer
          index: 0

      it 'should map from Inline FTML locations to string', ->
        attributedString = AttributedString.fromInlineFTMLString('Hel<b data-my="test">lo wo</b>rld!')
        inlineFTMLContainer = attributedString.toInlineFTMLFragment()

        node = inlineFTMLContainer.firstChild
        index = 0
        AttributedString.inlineFTMLIndexToTextIndex(node, index, inlineFTMLContainer).should.equal(0)

        node = inlineFTMLContainer.firstChild.nextSibling.firstChild
        index = 0
        AttributedString.inlineFTMLIndexToTextIndex(node, index, inlineFTMLContainer).should.equal(3)

        node = inlineFTMLContainer.firstChild.nextSibling.firstChild
        index = 1
        AttributedString.inlineFTMLIndexToTextIndex(node, index, inlineFTMLContainer).should.equal(4)

        node = inlineFTMLContainer.firstChild.nextSibling.nextSibling
        index = 4
        AttributedString.inlineFTMLIndexToTextIndex(node, index, inlineFTMLContainer).should.equal(12)

      it 'should map from empty Inline FTML to string locations', ->
        inlineFTMLContainer = document.createElement 'p'
        AttributedString.inlineFTMLIndexToTextIndex(inlineFTMLContainer, 0, inlineFTMLContainer).should.equal(0)