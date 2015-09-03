RunIndex = require '../../lib/core/run-index'

describe 'RunIndex', ->
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

    it 'finds attributes at character index', ->
      runIndex.getAttributesAtIndex(0).should.eql(a: '1')
      runIndex.getAttributesAtIndex(1).should.eql(a: '1')
      runIndex.getAttributesAtIndex(2).should.eql(a: '1', b: '2')
      runIndex.getAttributesAtIndex(3).should.eql(a: '1', b: '2')
      runIndex.getAttributesAtIndex(4).should.eql(b: '2')
      runIndex.getAttributesAtIndex(5).should.eql({})
      (-> runIndex.getAttributesAtIndex(runIndex, 6)).should.throw()

    it 'finds effective range of attributes at character index', ->
      range = {}
      runIndex.getAttributesAtIndex(0, range)
      range.should.eql(location: 0, length: 2)

      runIndex.getAttributesAtIndex(1, range)
      range.should.eql(location: 0, length: 2)

      runIndex.getAttributesAtIndex(2, range)
      range.should.eql(location: 2, length: 2)

      runIndex.getAttributesAtIndex(3, range)
      range.should.eql(location: 2, length: 2)

      runIndex.getAttributesAtIndex(4, range)
      range.should.eql(location: 4, length: 1)

      runIndex.getAttributesAtIndex(5, range)
      range.should.eql(location: 5, length: 1)

    it 'finds longest effective range of attribute at location', ->
      range = {}
      runIndex.getAttributeAtIndex('a', 0, null, range)
      range.should.eql(location: 0, length: 4)

      runIndex.getAttributeAtIndex('a', 1, null, range)
      range.should.eql(location: 0, length: 4)

      runIndex.getAttributeAtIndex('a', 2, null, range)
      range.should.eql(location: 0, length: 4)

      runIndex.getAttributeAtIndex('a', 3, null, range)
      range.should.eql(location: 0, length: 4)

      runIndex.getAttributeAtIndex('b', 4, null, range)
      range.should.eql(location: 2, length: 3)

      runIndex.getAttributeAtIndex('b', 5, null, range)
      range.should.eql(location: 2, length: 3)

      runIndex.getAttributeAtIndex('b', 6, null, range)
      range.should.eql(location: 5, length: 1)

      runIndex.getAttributeAtIndex('undefinedeverywhere', 4, null, range)
      range.should.eql(location: 0, length: 6)
