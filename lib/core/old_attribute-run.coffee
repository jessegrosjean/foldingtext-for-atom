# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

_ = require 'underscore-plus'

module.exports =
class AttributeRun
  constructor: (@location, @length, @attributes) ->

  copy: ->
    new AttributeRun(@location, @length, @copyAttributes())

  copyAttributes: ->
    JSON.parse(JSON.stringify(@attributes))

  splitAtIndex: (index) ->
    location = @location
    length = @length
    end = location + length
    @length = index - location
    newLength = (location + length) - index
    newAttributes = if index is end then {} else @copyAttributes()
    new AttributeRun(index, newLength, newAttributes)

  toString: ->
    attributes = @attributes
    sortedNames = for name of attributes then name
    sortedNames.sort()
    nameValues = ("#{name}=#{attributes[name]}" for name in sortedNames)
    "#{@location},#{@length}/#{nameValues.join("/")}"

  _mergeWithNext: (attributeRun) ->
    end = @location + @length
    endsAtStart = end is attributeRun.location
    if endsAtStart and _.isEqual(@attributes, attributeRun.attributes)
      @length += attributeRun.length
      true
    else
      false