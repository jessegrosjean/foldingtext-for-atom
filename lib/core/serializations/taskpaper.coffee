## Move this to separate package
require './text'

serializeItems = (items, editor, options) ->
  require('./text').serializeItems items, editor, (item) ->
    text = item.bodyString
    switch item.getAttribute('data-type')
      when 'project'
        text += ':'
      when 'task'
        text = '- ' + text
    text

extractType = (item) ->
  text = item.bodyString
  newText = text.trim()
  if newText.indexOf('- ') is 0
    item.setAttribute('data-type', 'task')
    newText = newText.substring(2)
  else if newText.match(/:$/)
    item.setAttribute('data-type', 'project')
    newText = newText.substr(0, newText.length - 1)

  if text isnt newText
    item.bodyString = newText

deserializeItems = (text, outline, options) ->
  items = require('./text').deserializeItems(text, outline)
  for each in items
    while each
      extractType(each)
      each = each.nextItem
  items

module.exports =
  serializeItems: serializeItems
  deserializeItems: deserializeItems

###
registerSerialization
  priority: 0
  extensions: ['taskpaper']
  mimeTypes: [Constants.TASKPAPERMimeType]
  serializeItems: (items, editor) ->
    require('./serializations/taskpaper').serializeItems(items, editor)
  deserializeItems: (itemsData, outline) ->
    require('./serializations/taskpaper').deserializeItems(itemsData, outline)
###

ItemSerializer = require '../../../lib/core/item-serializer'
loadOutlineFixture = require '../../load-outline-fixture'
Constants = require '../../../lib/core/constants'
Outline = require '../../../lib/core/outline'

fixtureAsTaskPaperString = '''
  one: @two
  \t- two @one @two
  \t\tthree @t
  \t\tfour @t
  \t- five
  \t\tsix @t(23)
'''

describe 'TASKPAPER Serialization', ->
  [outline, root, one, two, three, four, five, six] = []

  beforeEach ->
    {outline, root, one, two, three, four, five, six} = loadOutlineFixture()
    one.setAttribute('data-type', 'project')
    one.setAttribute('data-two', '')
    two.setAttribute('data-type', 'task')
    two.setAttribute('data-one', '')
    two.setAttribute('data-two', '')
    three.setAttribute('data-type', 'comment')
    four.setAttribute('data-type', 'comment')
    five.setAttribute('data-type', 'task')
    six.setAttribute('data-type', 'comment')
    six.setAttribute('data-t', '23')

  it 'should serialize items to TASKPAPER string', ->
    ItemSerializer.serializeItems(outline.root.children, null, Constants.TASKPAPERMimeType).should.equal(fixtureAsTaskPaperString)

  it 'should deserialize items from TASKPAPER string', ->
    one = ItemSerializer.deserializeItems(fixtureAsTaskPaperString, outline, Constants.TASKPAPERMimeType)[0]
    one.bodyString.should.equal('one')
    one.lastChild.bodyString.should.equal('five')
    one.lastChild.lastChild.getAttribute('data-t').should.equal('23')
    one.descendants.length.should.equal(5)