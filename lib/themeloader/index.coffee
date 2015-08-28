CSSParser = require './css-parser'
less = require './less'

module.exports = (lessText) ->
  result = null
  less.render lessText, {}, (error, cssResult) ->
    result = CSSParser.parse(cssResult.css)
  result