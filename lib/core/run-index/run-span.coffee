Span = require '../span-index/span'
_ = require 'underscore-plus'

class RunSpan extends Span

  @attributes: null

  constructor: (text, @attributes={}) ->
    super(text)

  clone: ->
    clone = super()
    clone.attributes = _.clone(@attributes)
    clone

  setAttributes: (attributes={}) ->
    @attributes = _.clone(attributes)

  addAttribute: (attribute, value) ->
    @attributes[attribute] = value

  addAttributes: (attributes) ->
    for k,v of attributes
      @attributes[k] = v

  removeAttribute: (attribute) ->
    delete @attributes[attribute]

  mergeWithSpan: (run) ->
    if _.isEqual(@attributes, run.attributes)
      @setString(@string + run.string)
      true
    else
      false

  toString: ->
    sortedNames = for name of @attributes then name
    sortedNames.sort()
    nameValues = ("#{name}:#{JSON.stringify(@attributes[name])}" for name in sortedNames)
    super(nameValues.join('/'))

module.exports = RunSpan