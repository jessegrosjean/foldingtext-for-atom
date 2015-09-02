RunIndex = require '../../lib/core/run-index'

fdescribe 'RunIndex', ->
  [runIndex] = []

  beforeEach ->
    runIndex = new RunIndex()

  afterEach ->
    runIndex.destroy()

  it 'starts empty', ->
    runIndex.toString().should.equal('')

  it 'sets attributes', ->
    runIndex.insertString(0, 'hello!')
    runIndex.setAttributesInRange(one: 'two', 0, 6)
    runIndex.toString().should.equal('(hello!/one:"two")')

  it 'adds attribute', ->
    runIndex.insertString(0, 'hello!')
    runIndex.setAttributesInRange(one: 'two', 0, 6)
    runIndex.addAttributeInRange('newattr', 'boo', 0, 6)
    runIndex.toString().should.equal('(hello!/newattr:"boo"/one:"two")')

  it 'adds attributes', ->
    runIndex.insertString(0, 'hello!')
    runIndex.setAttributesInRange(one: 'two', 0, 6)
    runIndex.addAttributesInRange(three: 'four', 0, 6)
    runIndex.toString().should.equal('(hello!/one:"two"/three:"four")')

  it 'removes attribute', ->
    runIndex.insertString(0, 'hello!')
    runIndex.setAttributesInRange(one: 'two', 0, 6)
    runIndex.removeAttributeInRange('one', 0, 6)
    runIndex.toString().should.equal('(hello!)')

  it 'splits attribute runs as needed', ->
    runIndex.insertString(0, 'hello!')
    runIndex.addAttributeInRange('one', 'two', 0, 1)
    runIndex.addAttributeInRange('one', 'two', 3, 1)
    runIndex.addAttributeInRange('one', 'two', 5, 1)
    runIndex.toString().should.equal('(h/one:"two")(el)(l/one:"two")(o)(!/one:"two")')

  describe 'Accessing Attributes', ->

    beforeEach ->
      runIndex.insertString(0, 'hello!')
      runIndex.addAttributesInRange(a: '1', 0, 4)
      runIndex.addAttributesInRange(b: '2', 2, 3)

    it 'finds attributes at offset', ->
      Adjust this to match NSAttributedString behavior
      runIndex.getAttributesAtOffset(0).should.eql(a: '1')
      runIndex.getAttributesAtOffset(1).should.eql(a: '1')
      runIndex.getAttributesAtOffset(2).should.eql(a: '1', b: '2')
      runIndex.getAttributesAtOffset(3).should.eql(a: '1', b: '2')
      runIndex.getAttributesAtOffset(4).should.eql(b: '2')
      runIndex.getAttributesAtOffset(5).should.eql({})
      runIndex.getAttributesAtOffset(6).should.eql({})

    it 'finds effective range of attributes at offset', ->
      range = {}
      runIndex.getAttributesAtOffset(0, range)
      range.should.eql(offset: 0, length: 2)

      runIndex.getAttributesAtOffset(3, range)
      range.should.eql(offset: 2, length: 2)

      runIndex.getAttributesAtOffset(4, range)
      range.should.eql(offset: 2, length: 2)

      runIndex.getAttributesAtOffset(5, range)
      range.should.eql(offset: 4, length: 1)

      runIndex.getAttributesAtOffset(6, range)
      range.should.eql(offset: 5, length: 1)

    it 'finds longest effective range of attribute at offset', ->
      range = {}
      runIndex.getAttributeAtOffset('a', 0, null, range)
      range.should.eql(offset: 0, length: 4)

      runIndex.getAttributeAtOffset('a', 3, null, range)
      range.should.eql(offset: 0, length: 4)

      runIndex.getAttributeAtOffset('b', 4, null, range)
      range.should.eql(offset: 2, length: 3)

      runIndex.getAttributeAtOffset('b', 5, null, range)
      range.should.eql(offset: 2, length: 3)

      runIndex.getAttributeAtOffset('b', 6, null, range)
      range.should.eql(offset: 5, length: 1)

      runIndex.getAttributeAtOffset('undefinedeverywhere', 4, null, range)
      range.should.eql(offset: 0, length: 6)
