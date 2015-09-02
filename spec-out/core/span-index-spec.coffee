SpanIndex = require '../../lib/core/span-index'

fdescribe 'SpanIndex', ->
  [spanIndex] = []

  beforeEach ->
    spanIndex = new SpanIndex()

  afterEach ->
    spanIndex.destroy()

  describe 'Init', ->

    it 'starts empty', ->
      spanIndex.getLength().should.equal(0)
      spanIndex.getSpanCount().should.equal(0)

    it 'can be cloned', ->
      spanIndex.createSpan('one').clone().getLength().should.equal(3)

  describe 'Empty', ->

    it 'insert text into empty, automatically insert span if needed', ->
      spanIndex.insertString(0, 'hello world')
      spanIndex.getLength().should.equal(11)
      spanIndex.getSpanCount().should.equal(1)

    it 'delete text to empty, leave last span in place', ->
      spanIndex.insertString(0, 'hello world')
      spanIndex.deleteRange(0, 11)
      spanIndex.getLength().should.equal(0)
      spanIndex.getSpanCount().should.equal(1)

  describe 'Spans', ->

    it 'find spans by offset', ->
      spanIndex.insertSpans(0, [spanIndex.createSpan('one'), spanIndex.createSpan('two')])
      spanIndex.getSpanAtOffset(0).should.eql(span: spanIndex.getSpan(0), index: 0, startOffset: 0, offset: 0)
      spanIndex.getSpanAtOffset(2).should.eql(span: spanIndex.getSpan(0), index: 0, startOffset: 0, offset: 2)
      spanIndex.getSpanAtOffset(3).should.eql(span: spanIndex.getSpan(1), index: 1, startOffset: 3, offset: 0)
      spanIndex.getSpanAtOffset(5).should.eql(span: spanIndex.getSpan(1), index: 1, startOffset: 3, offset: 2)
      spanIndex.getSpanAtOffset(6).should.eql(span: spanIndex.getSpan(1), index: 1, startOffset: 3, offset: 3)

  xdescribe 'Performance', ->

    it 'should handle 10,000 spans', ->

      console.profile('Create Spans')
      console.time('Create Spans')
      spanCount = 10000
      spans = []
      for i in [0..spanCount - 1]
        spans.push(spanIndex.createSpan('hello world!'))
      console.timeEnd('Create Spans')
      console.profileEnd()

      console.profile('Batch Insert Spans')
      console.time('Batch Insert Spans')
      spanIndex.insertSpans(0, spans)
      spanIndex.getSpanCount().should.equal(spanCount)
      spanIndex.getLength().should.equal(spanCount * 'hello world!'.length)
      console.timeEnd('Batch Insert Spans')
      console.profileEnd()

      console.profile('Batch Remove Spans')
      console.time('Batch Remove Spans')
      spanIndex.removeSpans(0, spanIndex.getSpanCount())
      spanIndex.getSpanCount().should.equal(0)
      spanIndex.getLength().should.equal(0)
      console.timeEnd('Batch Remove Spans')
      console.profileEnd()

      getRandomInt = (min, max) ->
        Math.floor(Math.random() * (max - min)) + min

      console.profile('Random Insert Spans')
      console.time('Random Insert Spans')
      for each in spans
        spanIndex.insertSpans(getRandomInt(0, spanIndex.getSpanCount()), [each])
      spanIndex.getSpanCount().should.equal(spanCount)
      spanIndex.getLength().should.equal(spanCount * 'hello world!'.length)
      console.timeEnd('Random Insert Spans')
      console.profileEnd()

      console.profile('Random Insert Text')
      console.time('Random Insert Text')
      for i in [0..spanCount - 1]
        spanIndex.insertString(getRandomInt(0, spanIndex.getLength()), 'Hello')
      spanIndex.getLength().should.equal(spanCount * 'hello world!Hello'.length)
      console.timeEnd('Random Insert Text')
      console.profileEnd()

      console.profile('Random Access Spans')
      console.time('Random Access Spans')
      for i in [0..spanCount - 1]
        start = getRandomInt(0, spanIndex.getSpanCount())
        end = getRandomInt(start, Math.min(start + 100, spanIndex.getSpanCount()))
        spanIndex.getSpans(start, end - start)
      console.timeEnd('Random Access Spans')
      console.profileEnd()

      console.profile('Random Remove Spans')
      console.time('Random Remove Spans')
      for each in spans
        spanIndex.removeSpans(getRandomInt(0, spanIndex.getSpanCount()), 1)
      spanIndex.getSpanCount().should.equal(0)
      spanIndex.getLength().should.equal(0)
      console.timeEnd('Random Remove Spans')
      console.profileEnd()