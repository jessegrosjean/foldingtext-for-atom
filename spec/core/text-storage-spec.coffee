TextStorage = require '../../lib/core/text-storage-ftml'

describe 'TextStorage', ->
  [textStorage] = []

  beforeEach ->
    textStorage = new TextStorage 'Hello world!'

  describe 'Get Substrings', ->

    it 'should get string', ->
      textStorage.getString().should.equal('Hello world!')

    it 'should get substring', ->
      textStorage.substr(0, 5).should.equal('Hello')
      textStorage.substr(6, 6).should.equal('world!')

    it 'should get attributed substring from start', ->
      substring = textStorage.subtextStorage(0, 5)
      substring.toString().should.equal('lines: (Hello) runs: (Hello)')

    it 'should get attributed substring from end', ->
      substring = textStorage.subtextStorage(6, 6)
      substring.toString().should.equal('lines: (world!) runs: (world!)')

    it 'should get empty attributed substring', ->
      textStorage.subtextStorage(1, 0).toString().should.equal('lines:  runs: ')

    it 'should get attributed substring with attributes', ->
      textStorage.addAttributeInRange('name', 'jesse', 0, 5)

      substring = textStorage.subtextStorage(0, 12)
      substring.toString().should.equal(textStorage.toString())

      substring = textStorage.subtextStorage(0, 5)
      substring.toString().should.equal('lines: (Hello) runs: (Hello/name:"jesse")')

    it 'should get attributed substring with overlapping attributes', ->
      textStorage.addAttributeInRange('i', null, 0, 12)
      textStorage.addAttributeInRange('b', null, 4, 3)
      textStorage.toString().should.equal('lines: (Hello world!) runs: (Hell/i:null)(o w/b:null/i:null)(orld!/i:null)')
      substring = textStorage.subtextStorage(6, 6)
      substring.toString().should.equal('lines: (world!) runs: (w/b:null/i:null)(orld!/i:null)')

  describe 'Delete Characters', ->

    it 'should delete from start', ->
      textStorage.deleteRange(0, 6)
      textStorage.toString().should.equal('lines: (world!) runs: (world!)')

    it 'should delete from end', ->
      textStorage.deleteRange(5, 7)
      textStorage.toString().should.equal('lines: (Hello) runs: (Hello)')

    it 'should delete from middle', ->
      textStorage.deleteRange(3, 5)
      textStorage.toString().should.equal('lines: (Helrld!) runs: (Helrld!)')

    it 'should adjust attribute run when deleting from start', ->
      textStorage.addAttributeInRange('b', null, 0, 5)
      textStorage.deleteRange(0, 1)
      textStorage.toString().should.equal('lines: (ello world!) runs: (ello/b:null)( world!)')

    it 'should adjust attribute run when deleting from end', ->
      textStorage.addAttributeInRange('b', null, 0, 5)
      textStorage.deleteRange(3, 2)
      textStorage.toString().should.equal('lines: (Hel world!) runs: (Hel/b:null)( world!)')

    it 'should adjust attribute run when deleting from middle', ->
      textStorage.addAttributeInRange('b', null, 0, 5)
      textStorage.deleteRange(2, 2)
      textStorage.toString().should.equal('lines: (Heo world!) runs: (Heo/b:null)( world!)')

    it 'should adjust attribute run when overlapping start', ->
      textStorage.addAttributeInRange('b', null, 6, 6)
      textStorage.deleteRange(5, 2)
      textStorage.toString().should.equal('lines: (Helloorld!) runs: (Hello)(orld!/b:null)')

    it 'should adjust attribute run when overlapping end', ->
      textStorage.addAttributeInRange('b', null, 0, 5)
      textStorage.deleteRange(4, 2)
      textStorage.toString().should.equal('lines: (Hellworld!) runs: (Hell/b:null)(world!)')

    it 'should remove attribute run when covering from start', ->
      textStorage.addAttributeInRange('b', null, 0, 5)
      textStorage.deleteRange(0, 6)
      textStorage.toString().should.equal('lines: (world!) runs: (world!)')

    it 'should remove attribute run when covering from end', ->
      textStorage.addAttributeInRange('b', null, 6, 6)
      textStorage.deleteRange(5, 7)
      textStorage.toString().should.equal('lines: (Hello) runs: (Hello)')

  describe 'Insert String', ->

    it 'should insert at start', ->
      textStorage.insertText(0, 'Boo!')
      textStorage.toString().should.equal('lines: (Boo!Hello world!) runs: (Boo!Hello world!)')

    it 'should insert at end', ->
      textStorage.insertText(12, 'Boo!')
      textStorage.toString().should.equal('lines: (Hello world!Boo!) runs: (Hello world!Boo!)')

    it 'should insert in middle', ->
      textStorage.insertText(6, 'Boo!')
      textStorage.toString().should.equal('lines: (Hello Boo!world!) runs: (Hello Boo!world!)')

    it 'should insert into empty string', ->
      textStorage.deleteRange(0, 12)
      textStorage.insertText(0, 'Boo!')
      textStorage.toString().should.equal('lines: (Boo!) runs: (Boo!)')

    it 'should adjust attribute run when inserting at run start', ->
      textStorage.addAttributeInRange('b', null, 0, 5)
      textStorage.insertText(0, 'Boo!')
      textStorage.toString().should.equal('lines: (Boo!Hello world!) runs: (Boo!Hello/b:null)( world!)')

    it 'should adjust attribute run when inserting at run end', ->
      textStorage.addAttributeInRange('b', null, 0, 5)
      textStorage.insertText(5, 'Boo!')
      textStorage.toString().should.equal('lines: (HelloBoo! world!) runs: (HelloBoo!/b:null)( world!)')

    it 'should adjust attribute run when inserting in run middle', ->
      textStorage.addAttributeInRange('b', null, 0, 5)
      textStorage.insertText(3, 'Boo!')
      textStorage.toString().should.equal('lines: (HelBoo!lo world!) runs: (HelBoo!lo/b:null)( world!)')

    it 'should insert attributed string including runs', ->
      insert = new TextStorage('Boo!')
      insert.addAttributeInRange('i', null, 0, 3)
      insert.addAttributeInRange('b', null, 1, 3)
      textStorage.insertText(0, insert)
      textStorage.toString().should.equal('lines: (Boo!Hello world!) runs: (B/i:null)(oo/b:null/i:null)(!/b:null)(Hello world!)')

  describe 'Replace Substrings', ->

    it 'should update attribute runs when attributed string is modified', ->
      textStorage.addAttributeInRange('name', 'jesse', 0, 12)
      textStorage.replaceRangeWithText(0, 12, 'Hello')
      textStorage.toString().should.equal('lines: (Hello) runs: (Hello/name:"jesse")')
      textStorage.replaceRangeWithText(5, 0, ' World!')
      textStorage.toString().should.equal('lines: (Hello World!) runs: (Hello World!/name:"jesse")')

    it 'should update attribute runs when node text is paritially updated', ->
      textStorage.addAttributeInRange('name', 'jesse', 0, 5)
      textStorage.addAttributeInRange('name', 'joe', 5, 7)
      textStorage.toString(true).should.equal('lines: (Hello world!) runs: (Hello/name:"jesse")( world!/name:"joe")')

      textStorage.replaceRangeWithText(3, 5, '')
      textStorage.toString(true).should.equal('lines: (Helrld!) runs: (Hel/name:"jesse")(rld!/name:"joe")')

      textStorage.replaceRangeWithText(3, 0, 'lo wo')
      textStorage.toString(true).should.equal('lines: (Hello world!) runs: (Hello wo/name:"jesse")(rld!/name:"joe")')

    it 'should remove leading attribute run if text in run is fully replaced', ->
      textStorage = new TextStorage('\ttwo')
      textStorage.addAttributeInRange('name', 'jesse', 0, 1)
      textStorage.replaceRangeWithText(0, 1, '')
      textStorage.toString().should.equal('lines: (two) runs: (two)')

    it 'should retain attributes of fully replaced range if replacing string length is not zero.', ->
      textStorage = new TextStorage('\ttwo')
      textStorage.addAttributeInRange('name', 'jesse', 0, 1)
      textStorage.replaceRangeWithText(0, 1, 'h')
      textStorage.toString().should.equal('lines: (htwo) runs: (h/name:"jesse")(two)')

    it 'should allow inserting of another attributed string', ->
      newString = new TextStorage('two')
      newString.addAttributeInRange('b', null, 0, 3)

      textStorage.addAttributeInRange('i', null, 0, 12)
      textStorage.replaceRangeWithText(5, 1, newString)
      textStorage.toString().should.equal('lines: (Hellotwoworld!) runs: (Hello/i:null)(two/b:null)(world!/i:null)')

  describe 'Add/Remove/Find Attributes', ->

    it 'should add attribute run', ->
      range = {}
      textStorage.addAttributeInRange('name', 'jesse', 0, 5)
      textStorage.getAttributesAtIndex(0, range).name.should.equal('jesse')
      range.location.should.equal(0)
      range.length.should.equal(5)
      textStorage.getAttributesAtIndex(5, range).should.eql({})
      range.location.should.equal(5)
      range.length.should.equal(7)

    it 'should add attribute run bordering start of string', ->
      range = {}
      textStorage.addAttributeInRange('name', 'jesse', 0, 5)
      textStorage.getAttributesAtIndex(0, range).name.should.equal('jesse')
      range.location.should.equal(0)
      range.length.should.equal(5)

    it 'should add attribute run bordering end of string', ->
      range = {}
      textStorage.addAttributeInRange('name', 'jesse', 6, 6)
      textStorage.getAttributesAtIndex(6, range).name.should.equal('jesse')
      range.location.should.equal(6)
      range.length.should.equal(6)

    it 'should find longest effective range for attribute', ->
      longestEffectiveRange = {}
      textStorage.addAttributeInRange('one', 'one', 0, 12)
      textStorage.addAttributeInRange('two', 'two', 6, 6)
      textStorage.getAttributeAtIndex('one', 6, null, longestEffectiveRange).should.equal('one')
      longestEffectiveRange.should.eql(location: 0, length: 12)

    it 'should add multiple attributes in same attribute run', ->
      range = {}
      textStorage.addAttributeInRange('name', 'jesse', 0, 5)
      textStorage.addAttributeInRange('age', '35', 0, 5)
      textStorage.getAttributesAtIndex(0, range).name.should.equal('jesse')
      textStorage.getAttributesAtIndex(0, range).age.should.equal('35')
      range.location.should.equal(0)
      range.length.should.equal(5)

    it 'should add attributes in overlapping ranges', ->
      range = {}
      textStorage.addAttributeInRange('name', 'jesse', 0, 5)
      textStorage.addAttributeInRange('age', '35', 3, 5)

      textStorage.getAttributesAtIndex(0, range).name.should.equal('jesse')
      (textStorage.getAttributesAtIndex(0, range).age is undefined).should.be.true
      range.location.should.equal(0)
      range.length.should.equal(3)

      textStorage.getAttributesAtIndex(3, range).name.should.equal('jesse')
      textStorage.getAttributesAtIndex(3, range).age.should.equal('35')
      range.location.should.equal(3)
      range.length.should.equal(2)

      (textStorage.getAttributesAtIndex(6, range).name is undefined).should.be.true
      textStorage.getAttributesAtIndex(6, range).age.should.equal('35')
      range.location.should.equal(5)
      range.length.should.equal(3)

    it 'should allow removing attributes in range', ->
      textStorage.addAttributeInRange('name', 'jesse', 0, 12)
      textStorage.removeAttributeInRange('name', 0, 12)
      textStorage.toString(true).should.equal('lines: (Hello world!) runs: (Hello world!)')

      textStorage.addAttributeInRange('name', 'jesse', 0, 12)
      textStorage.removeAttributeInRange('name', 0, 3)
      textStorage.toString(true).should.equal('lines: (Hello world!) runs: (Hel)(lo world!/name:"jesse")')

      textStorage.removeAttributeInRange('name', 9, 3)
      textStorage.toString(true).should.equal('lines: (Hello world!) runs: (Hel)(lo wor/name:"jesse")(ld!)')

    it 'should throw when accessing attributes past end of string', ->
      (-> textStorage.getAttributesAtIndex(11)).should.not.throw()
      (-> textStorage.getAttributesAtIndex(12)).should.throw()
      textStorage.replaceRangeWithText(0, 12, '')
      (-> textStorage.getAttributesAtIndex(0)).should.throw()

  describe 'Inline FTML', ->

    beforeEach ->
      textStorage = new TextStorage 'Hello world!'

    describe 'To Inline FTML', ->

      it 'should convert to Inline FTML', ->
        textStorage.toInlineFTMLString().should.equal('Hello world!')

      it 'should convert to Inline FTML with attributes', ->
        textStorage.addAttributeInRange('B', 'data-my': 'test', 3, 5)
        textStorage.toInlineFTMLString().should.equal('Hel<b data-my="test">lo wo</b>rld!')

      it 'should convert empty to Inline FTML', ->
        new TextStorage().toInlineFTMLString().should.equal('')

    describe 'From Inline FTML', ->

      it 'should convert from Inline FTML', ->
        TextStorage.fromInlineFTMLString('Hello world!').toString().should.equal('lines: (Hello world!) runs: (Hello world!)')

      it 'should convert from Inline FTML with attributes', ->
        TextStorage.fromInlineFTMLString('Hel<b data-my="test">lo wo</b>rld!').toString().should.equal('lines: (Hello world!) runs: (Hel)(lo wo/B:{"data-my":"test"})(rld!)')

      it 'should convert from empty Inline FTML', ->
        TextStorage.fromInlineFTMLString('').toString().should.equal('lines:  runs: ')

    describe 'Offset Mapping', ->

      it 'should map from string to Inline FTML locations', ->
        textStorage = TextStorage.fromInlineFTMLString('Hel<b data-my="test">lo wo</b>rld!')
        inlineFTMLContainer = textStorage.toInlineFTMLFragment()

        TextStorage.textIndexToInlineFTMLIndex(0, inlineFTMLContainer).should.eql
          node: inlineFTMLContainer.firstChild
          index: 0

        TextStorage.textIndexToInlineFTMLIndex(3, inlineFTMLContainer).should.eql
          node: inlineFTMLContainer.firstChild
          index: 3

        TextStorage.textIndexToInlineFTMLIndex(4, inlineFTMLContainer).should.eql
          node: inlineFTMLContainer.firstChild.nextSibling.firstChild
          index: 1

        TextStorage.textIndexToInlineFTMLIndex(12, inlineFTMLContainer).should.eql
          node: inlineFTMLContainer.firstChild.nextSibling.nextSibling
          index: 4

      it 'should map from string to empty Inline FTML locations', ->
        inlineFTMLContainer = document.createElement 'p'
        TextStorage.textIndexToInlineFTMLIndex(0, inlineFTMLContainer).should.eql
          node: inlineFTMLContainer
          index: 0

      it 'should map from Inline FTML locations to string', ->
        textStorage = TextStorage.fromInlineFTMLString('Hel<b data-my="test">lo wo</b>rld!')
        inlineFTMLContainer = textStorage.toInlineFTMLFragment()

        node = inlineFTMLContainer.firstChild
        index = 0
        TextStorage.inlineFTMLIndexToTextIndex(node, index, inlineFTMLContainer).should.equal(0)

        node = inlineFTMLContainer.firstChild.nextSibling.firstChild
        index = 0
        TextStorage.inlineFTMLIndexToTextIndex(node, index, inlineFTMLContainer).should.equal(3)

        node = inlineFTMLContainer.firstChild.nextSibling.firstChild
        index = 1
        TextStorage.inlineFTMLIndexToTextIndex(node, index, inlineFTMLContainer).should.equal(4)

        node = inlineFTMLContainer.firstChild.nextSibling.nextSibling
        index = 4
        TextStorage.inlineFTMLIndexToTextIndex(node, index, inlineFTMLContainer).should.equal(12)

      it 'should map from empty Inline FTML to string locations', ->
        inlineFTMLContainer = document.createElement 'p'
        TextStorage.inlineFTMLIndexToTextIndex(inlineFTMLContainer, 0, inlineFTMLContainer).should.equal(0)