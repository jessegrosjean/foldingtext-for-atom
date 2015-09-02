TextStorage = require '../../lib/core/text-storage-ftml'

describe 'TextStorage', ->
  [textStorage] = []

  beforeEach ->
    textStorage = new TextStorage()

  afterEach ->
    textStorage.destroy()

  it 'starts empty', ->
    textStorage.getLength().should.equal(0)
    textStorage.toString().should.equal('lines:  runs: ')

  it 'inserts text', ->
    textStorage.insertString(0, 'one')
    textStorage.insertString(2, 'moose')
    textStorage.toString().should.equal('lines: (onmoosee) runs: (onmoosee)')

  it 'deletes text', ->
    textStorage.insertString(0, 'one')
    textStorage.deleteRange(1, 1)
    textStorage.toString().should.equal('lines: (oe) runs: (oe)')

  it 'gets subtextStorage', ->
    textStorage.insertString(0, 'one\ntwo')
    textStorage.addAttributeInRange('a', 'a', 0, 5)
    textStorage.addAttributeInRange('b', 'b', 2, 5)
    textStorage.toString().should.equal('lines: (one\n)(two) runs: (on/a:"a")(e\nt/a:"a"/b:"b")(wo/b:"b")')
    textStorage.subtextStorage(0, 2).toString().should.equal('lines: (on) runs: (on/a:"a")')
    textStorage.subtextStorage(0, 1).toString().should.equal('lines: (o) runs: (o/a:"a")')
    textStorage.subtextStorage(1, 4).toString().should.equal('lines: (ne\n)(t) runs: (n/a:"a")(e\nt/a:"a"/b:"b")')

  it 'appends textStorage', ->
    textStorage.insertString(0, 'one')
    textStorage.addAttributeInRange('a', 'a', 0, 3)
    append = new TextStorage()
    append.insertString(0, 'two')
    append.addAttributeInRange('b', 'b', 0, 3)
    textStorage.appendTextStorage(append)
    textStorage.toString().should.equal('lines: (onetwo) runs: (one/a:"a")(two/b:"b")')

  it 'inserts textStorage', ->
    textStorage.insertString(0, 'one')
    textStorage.addAttributeInRange('a', 'a', 0, 3)
    insert = new TextStorage()
    insert.insertString(0, 'two')
    insert.addAttributeInRange('b', 'b', 0, 3)
    textStorage.insertTextStorage(2, insert)
    textStorage.toString().should.equal('lines: (ontwoe) runs: (on/a:"a")(two/b:"b")(e/a:"a")')

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

      it 'should map from string to Inline FTML offsets', ->
        textStorage = TextStorage.fromInlineFTMLString('Hel<b data-my="test">lo wo</b>rld!')
        inlineFTMLContainer = textStorage.toInlineFTMLFragment()

        TextStorage.textOffsetToInlineFTMLOffset(0, inlineFTMLContainer).should.eql
          node: inlineFTMLContainer.firstChild
          offset: 0

        TextStorage.textOffsetToInlineFTMLOffset(3, inlineFTMLContainer).should.eql
          node: inlineFTMLContainer.firstChild
          offset: 3

        TextStorage.textOffsetToInlineFTMLOffset(4, inlineFTMLContainer).should.eql
          node: inlineFTMLContainer.firstChild.nextSibling.firstChild
          offset: 1

        TextStorage.textOffsetToInlineFTMLOffset(12, inlineFTMLContainer).should.eql
          node: inlineFTMLContainer.firstChild.nextSibling.nextSibling
          offset: 4

      it 'should map from string to empty Inline FTML offsets', ->
        inlineFTMLContainer = document.createElement 'p'
        TextStorage.textOffsetToInlineFTMLOffset(0, inlineFTMLContainer).should.eql
          node: inlineFTMLContainer
          offset: 0

      it 'should map from Inline FTML offsets to string', ->
        textStorage = TextStorage.fromInlineFTMLString('Hel<b data-my="test">lo wo</b>rld!')
        inlineFTMLContainer = textStorage.toInlineFTMLFragment()

        node = inlineFTMLContainer.firstChild
        offset = 0
        TextStorage.inlineFTMLOffsetToTextOffset(node, offset, inlineFTMLContainer).should.equal(0)

        node = inlineFTMLContainer.firstChild.nextSibling.firstChild
        offset = 0
        TextStorage.inlineFTMLOffsetToTextOffset(node, offset, inlineFTMLContainer).should.equal(3)

        node = inlineFTMLContainer.firstChild.nextSibling.firstChild
        offset = 1
        TextStorage.inlineFTMLOffsetToTextOffset(node, offset, inlineFTMLContainer).should.equal(4)

        node = inlineFTMLContainer.firstChild.nextSibling.nextSibling
        offset = 4
        TextStorage.inlineFTMLOffsetToTextOffset(node, offset, inlineFTMLContainer).should.equal(12)

      it 'should map from empty Inline FTML to string offsets', ->
        inlineFTMLContainer = document.createElement 'p'
        TextStorage.inlineFTMLOffsetToTextOffset(inlineFTMLContainer, 0, inlineFTMLContainer).should.equal(0)










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
      textStorage.toString().should.equal('lines: (Heo world!) runs: (He/b:null)(o/b:null)( world!)')

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
      textStorage.insertString(0, 'Boo!')
      textStorage.toString().should.equal('lines: (Boo!Hello world!) runs: (Boo!Hello world!)')

    it 'should insert at end', ->
      textStorage.insertString(12, 'Boo!')
      textStorage.toString().should.equal('lines: (Hello world!Boo!) runs: (Hello world!Boo!)')

    it 'should insert in middle', ->
      textStorage.insertString(6, 'Boo!')
      textStorage.toString().should.equal('lines: (Hello Boo!world!) runs: (Hello Boo!world!)')

    it 'should insert into empty string', ->
      textStorage.deleteRange(0, 12)
      textStorage.insertString(0, 'Boo!')
      textStorage.toString().should.equal('lines: (Boo!) runs: (Boo!)')

    it 'should adjust attribute run when inserting at run start', ->
      textStorage.addAttributeInRange('b', null, 0, 5)
      textStorage.insertString(0, 'Boo!')
      textStorage.toString().should.equal('lines: (Boo!Hello world!) runs: (Boo!Hello/b:null)( world!)')

    it 'should adjust attribute run when inserting at run end', ->
      textStorage.addAttributeInRange('b', null, 0, 5)
      textStorage.insertString(5, 'Boo!')
      textStorage.toString().should.equal('lines: (HelloBoo! world!) runs: (HelloBoo!/b:null)( world!)')

    it 'should adjust attribute run when inserting in run middle', ->
      textStorage.addAttributeInRange('b', null, 0, 5)
      textStorage.insertString(3, 'Boo!')
      textStorage.toString().should.equal('lines: (HelBoo!lo world!) runs: (HelBoo!lo/b:null)( world!)')

    it 'should insert attributed string including runs', ->
      insert = new TextStorage('Boo!')
      insert.addAttributeInRange('i', null, 0, 3)
      insert.addAttributeInRange('b', null, 1, 3)
      textStorage.insertTextStorage(0, insert)
      textStorage.toString().should.equal('lines: (Boo!Hello world!) runs: (B/i:null)(oo/b:null/i:null)(!/b:null)(Hello world!)')

  describe 'Replace Substrings', ->

    it 'should update attribute runs when attributed string is modified', ->
      textStorage.addAttributeInRange('name', 'jesse', 0, 12)
      textStorage.replaceRangeWithString(0, 12, 'Hello')
      textStorage.toString().should.equal('lines: (Hello) runs: (Hello/name:"jesse")')
      textStorage.replaceRangeWithString(5, 0, ' World!')
      textStorage.toString().should.equal('lines: (Hello World!) runs: (Hello World!/name:"jesse")')

    it 'should update attribute runs when node text is paritially updated', ->
      textStorage.addAttributeInRange('name', 'jesse', 0, 5)
      textStorage.addAttributeInRange('name', 'joe', 5, 7)
      textStorage.toString(true).should.equal('lines: (Hello world!) runs: (Hello/name:"jesse")( world!/name:"joe")')

      textStorage.replaceRangeWithString(3, 5, '')
      textStorage.toString(true).should.equal('lines: (orld!) runs: (Hel/name:"jesse")(rld!/name:"joe")')

      textStorage.replaceRangeWithString(3, 0, 'lo wo')
      textStorage.toString(true).should.equal('lines: (orllo wo) runs: (Hello wo/name:"jesse")(rld!/name:"joe")')

    it 'should remove leading attribute run if text in run is fully replaced', ->
      textStorage = new TextStorage('\ttwo')
      textStorage.addAttributeInRange('name', 'jesse', 0, 1)
      textStorage.replaceRangeWithString(0, 1, '')
      textStorage.toString().should.equal('lines: (two) runs: (two)')

    it 'should retain attributes of fully replaced range if replacing string length is not zero.', ->
      textStorage = new TextStorage('\ttwo')
      textStorage.addAttributeInRange('name', 'jesse', 0, 1)
      textStorage.replaceRangeWithString(0, 1, 'h')
      textStorage.toString().should.equal('lines: (htwo) runs: (h/name:"jesse")(two)')

    it 'should allow inserting of another attributed string', ->
      newString = new TextStorage('two')
      newString.addAttributeInRange('b', null, 0, 3)

      textStorage.addAttributeInRange('i', null, 0, 12)
      textStorage.replaceRangeWithTextStorage(5, 1, newString)
      textStorage.toString().should.equal('lines: (Hellotwoworld!) runs: (Hello/i:null)(two/b:null)(world!/i:null)')

  describe 'Add/Remove/Find Attributes', ->

    fit 'should add attribute run', ->
      range = {}
      debugger
      textStorage.addAttributeInRange('name', 'jesse', 0, 5)
      textStorage.getAttributesAtOffset(0, range).name.should.equal('jesse')
      range.offset.should.equal(0)
      range.length.should.equal(5)
      textStorage.getAttributesAtOffset(5, range).should.eql({})
      range.offset.should.equal(5)
      range.length.should.equal(7)

    it 'should add attribute run bordering start of string', ->
      range = {}
      textStorage.addAttributeInRange('name', 'jesse', 0, 5)
      textStorage.getAttributesAtOffset(0, range).name.should.equal('jesse')
      range.offset.should.equal(0)
      range.length.should.equal(5)

    it 'should add attribute run bordering end of string', ->
      range = {}
      textStorage.addAttributeInRange('name', 'jesse', 6, 6)
      textStorage.getAttributesAtOffset(6, range).name.should.equal('jesse')
      range.offset.should.equal(6)
      range.length.should.equal(6)

    it 'should find longest effective range for attribute', ->
      longestEffectiveRange = {}
      textStorage.addAttributeInRange('one', 'one', 0, 12)
      textStorage.addAttributeInRange('two', 'two', 6, 6)
      textStorage.attributeAtIndex('one', 6, null, longestEffectiveRange).should.equal('one')
      longestEffectiveRange.location.should.equal(0)
      longestEffectiveRange.length.should.equal(12)

    it 'should find longest effective range for attributes', ->
      longestEffectiveRange = {}
      textStorage.addAttributeInRange('one', 'one', 0, 12)
      textStorage.addAttributeInRange('two', 'two', 6, 6)
      textStorage._indexOfAttributeRunForCharacterIndex(10) # artificial split
      textStorage.getAttributesAtOffset(6, null, longestEffectiveRange)
      longestEffectiveRange.location.should.equal(6)
      longestEffectiveRange.length.should.equal(6)

    it 'should add multiple attributes in same attribute run', ->
      range = {}
      textStorage.addAttributeInRange('name', 'jesse', 0, 5)
      textStorage.addAttributeInRange('age', '35', 0, 5)
      textStorage.getAttributesAtOffset(0, range).name.should.equal('jesse')
      textStorage.getAttributesAtOffset(0, range).age.should.equal('35')
      range.offset.should.equal(0)
      range.length.should.equal(5)

    it 'should add attributes in overlapping ranges', ->
      range = {}
      textStorage.addAttributeInRange('name', 'jesse', 0, 5)
      textStorage.addAttributeInRange('age', '35', 3, 5)

      textStorage.getAttributesAtOffset(0, range).name.should.equal('jesse')
      (textStorage.getAttributesAtOffset(0, range).age is undefined).should.be.true
      range.offset.should.equal(0)
      range.length.should.equal(3)

      textStorage.getAttributesAtOffset(3, range).name.should.equal('jesse')
      textStorage.getAttributesAtOffset(3, range).age.should.equal('35')
      range.offset.should.equal(3)
      range.length.should.equal(2)

      (textStorage.getAttributesAtOffset(6, range).name is undefined).should.be.true
      textStorage.getAttributesAtOffset(6, range).age.should.equal('35')
      range.offset.should.equal(5)
      range.length.should.equal(3)

    it 'should allow removing attributes in range', ->
      textStorage.addAttributeInRange('name', 'jesse', 0, 12)
      textStorage.removeAttributeInRange('name', 0, 12)
      textStorage.toString(true).should.equal('(Hello world!/)')

      textStorage.addAttributeInRange('name', 'jesse', 0, 12)
      textStorage.removeAttributeInRange('name', 0, 3)
      textStorage.toString(true).should.equal('(Hel/)(lo world!/name="jesse")')

      textStorage.removeAttributeInRange('name', 9, 3)
      textStorage.toString(true).should.equal('(Hel/)(lo wor/name="jesse")(ld!/)')

    it 'should return null when accessing attributes at end of string', ->
      expect(textStorage.getAttributesAtOffset(0, null) isnt null).toBe(true)
      expect(textStorage.getAttributesAtOffset(11, null) isnt null).toBe(true)
      expect(textStorage.getAttributesAtOffset(12, null) is null).toBe(true)
      textStorage.replaceCharactersInRange('', 0, 12)
      expect(textStorage.getAttributesAtOffset(0, null) is null).toBe(true)