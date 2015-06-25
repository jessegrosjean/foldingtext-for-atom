Constants = require '../lib/core/constants'
Outline = require '../lib/core/outline'
path = require 'path'
fs = require 'fs'

# one
#   two
#     three
#     four
#   five
#     six

module.exports = ->
  unless @outlineTemplate
    @outlineTemplate = new Outline()
    @outlineTemplate.loadSync(path.join(__dirname, 'fixtures/outline [loo!]!@#$%^&()-+.ftml'))

  outline = new Outline()
  for each in @outlineTemplate.root.children
    outline.root.appendChild(outline.importItem(each))

  {} =
      outline: outline
      root: outline.root
      one: outline.getItemForID('1')
      two: outline.getItemForID('2')
      three: outline.getItemForID('3')
      four: outline.getItemForID('4')
      five: outline.getItemForID('5')
      six: outline.getItemForID('6')