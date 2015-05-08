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
  unless @outlineRootTemplate
    parser = new DOMParser()
    outlinePath = path.join(__dirname, 'fixtures/outline.ftml')
    outlineBML = fs.readFileSync(outlinePath, 'utf8')
    outlineHTMLTemplate = parser.parseFromString(outlineBML, 'text/html')
    @outlineRootTemplate = outlineHTMLTemplate.getElementById Constants.RootID

  outlineHTML = document.implementation.createHTMLDocument()
  outlineRoot = outlineHTML.importNode @outlineRootTemplate, true
  outlineHTML.documentElement.lastChild.appendChild(outlineRoot)
  outline = new Outline({outlineStore: outlineHTML})

  {} =
      outline: outline
      root: outline.root
      one: outline.getItemForID('1')
      two: outline.getItemForID('2')
      three: outline.getItemForID('3')
      four: outline.getItemForID('4')
      five: outline.getItemForID('5')
      six: outline.getItemForID('6')