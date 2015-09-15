# Copyright (c) 2015 Jesse Grosjean. All rights reserved.

ItemPathParser = require './item-path-parser'
_ = require 'underscore-plus'

module.exports=
class ItemPath

  @parse: (path, startRule, types) ->
    startRule ?= 'ItemPathExpression'
    exception = null
    keywords = []
    parsedPath

    try
      parsedPath = ItemPathParser.parse path,
        startRule: startRule
        types: types
    catch e
      exception = e

    if parsedPath
      keywords = parsedPath.keywords

    {} =
      parsedPath: parsedPath
      keywords: keywords
      error: exception

  @evaluate: (itemPath, contextItem, options) ->
    options ?= {}
    if _.isString itemPath
      itemPath = new ItemPath itemPath, options
    itemPath.options = options
    results = itemPath.evaluate contextItem
    itemPath.options = options
    results

  constructor: (@pathExpressionString, @options) ->
    @options ?= {}
    parsed = @constructor.parse(@pathExpressionString, undefined, @options.types)
    @pathExpressionAST = parsed.parsedPath
    @pathExpressionKeywords = parsed.keywords
    @pathExpressionError = parsed.error

  ###
  Section: Evaluation
  ###

  evaluate: (item) ->
    if @pathExpressionAST
      @evaluatePathExpression @pathExpressionAST, item
    else
      []

  evaluatePathExpression: (pathExpressionAST, item) ->
    union = pathExpressionAST.union
    intersect = pathExpressionAST.intersect
    except = pathExpressionAST.except
    results

    if union
      results = @evaluateUnion union, item
    else if intersect
      results = @evaluateIntersect intersect, item
    else if except
      results = @evaluateExcept except, item
    else
      results = @evaluatePath pathExpressionAST, item

    @sliceResultsFrom pathExpressionAST.slice, results, 0

    results

  unionOutlineOrderedResults: (results1, results2, outline) ->
    results = []
    i = 0
    j = 0

    while true
      r1 = results1[i]
      r2 = results2[j]
      unless r1
        if r2
          results.push.apply(results, results2.slice(j))
        return results
      else unless r2
        if r1
          results.push.apply(results, results1.slice(i))
        return results
      else if r1 is r2
        results.push(r2)
        i++
        j++
      else
        if r1.row < r2.row
          results.push(r1)
          i++
        else
          results.push(r2)
          j++

  evaluateUnion: (pathsAST, item) ->
    results1 = @evaluatePathExpression pathsAST[0], item
    results2 = @evaluatePathExpression pathsAST[1], item
    @unionOutlineOrderedResults results1, results2, item.outline

  evaluateIntersect: (pathsAST, item) ->
    results1 = @evaluatePathExpression pathsAST[0], item
    results2 = @evaluatePathExpression pathsAST[1], item
    results = []
    i = 0
    j = 0

    while true
      r1 = results1[i]
      r2 = results2[j]

      unless r1
        return results
      else unless r2
        return results
      else if r1 is r2
        results.push(r2)
        i++
        j++
      else
        if r1.row < r2.row
          i++
        else
          j++

  evaluateExcept: (pathsAST, item) ->
    results1 = @evaluatePathExpression pathsAST[0], item
    results2 = @evaluatePathExpression pathsAST[1], item
    results = []
    i = 0
    j = 0

    while true
      r1 = results1[i]
      r2 = results2[j]

      while r1 and r2 and (r1.row > r2.row)
        j++
        r2 = results2[j]

      unless r1
        return results
      else unless r2
        results.push.apply(results, results1.slice(i))
        return results
      else if r1 is r2
        r1Index = -1
        r2Index = -1
        i++
        j++
      else
        results.push(r1)
        r1Index = -1
        i++

  evaluatePath: (pathAST, item) ->
    outline = item.outline
    contexts = []
    results

    if pathAST.absolute
      item = @options.root or item.root

    contexts.push item

    for step in pathAST.steps
      results = []
      for context in contexts
        if results.length
          # If evaluating from multiple contexts and we have some results
          # already merge the new set of context results in with the existing.
          contextResults = []
          @evaluateStep step, context, contextResults
          results = @unionOutlineOrderedResults results, contextResults, outline
        else
          @evaluateStep step, context, results
      contexts = results
    results

  evaluateStep: (step, item, results) ->
    predicate = step.predicate
    from = results.length
    type = step.type

    switch step.axis
      when 'ancestor-or-self'
        each = item
        while each
          if @evaluatePredicate type, predicate, each
            results.splice from, 0, each
          each = each.parent

      when 'ancestor'
        each = item.parent
        while each
          if @evaluatePredicate type, predicate, each
            results.splice from, 0, each
          each = each.parent

      when 'child'
        each = item.firstChild
        while each
          if @evaluatePredicate type, predicate, each
            results.push each
          each = each.nextSibling

      when 'descendant-or-self'
        end = item.nextBranch
        each = item
        while each and each isnt end
          if @evaluatePredicate type, predicate, each
            results.push each
          each = each.nextItem

      when 'descendant'
        end = item.nextBranch
        each = item.firstChild
        while each and each isnt end
          if @evaluatePredicate type, predicate, each
            results.push each
          each = each.nextItem

      when 'following-sibling'
        each = item.nextSibling
        while each
          if @evaluatePredicate type, predicate, each
            results.push each
          each = each.nextSibling

      when 'following'
        each = item.nextItem
        while each
          if @evaluatePredicate type, predicate, each
            results.push each
          each = each.nextItem

      when 'parent'
        each = item.parent
        if each and @evaluatePredicate type, predicate, each
          results.push each

      when 'preceding-sibling'
        each = item.previousSibling
        while each
          if @evaluatePredicate type, predicate, each
            results.splice from, 0, each
          each = each.previousSibling

      when 'preceding'
        each = item.previousItem
        while each
          if @evaluatePredicate type, predicate, each
            results.splice from, 0, each
          each = each.previousItem

      when 'self'
        if @evaluatePredicate type, predicate, item
          results.push item

    @sliceResultsFrom step.slice, results, from

  evaluatePredicate: (type, predicate, item) ->
    if type isnt '*' and type isnt item.getAttribute 'data-type'
      false
    else if predicate is '*'
      true
    else if andP = predicate.and
      @evaluatePredicate('*', andP[0], item) and @evaluatePredicate('*', andP[1], item)
    else if orP = predicate.or
      @evaluatePredicate('*', orP[0], item) or @evaluatePredicate('*', orP[1], item)
    else if notP = predicate.not
      not @evaluatePredicate '*', notP, item
    else
      attributePath = predicate.attributePath
      relation = predicate.relation
      modifier = predicate.modifier
      value = predicate.value

      if not relation and not value
        return @valueForAttributePath(attributePath, item) isnt undefined

      predicateValueCache = predicate.predicateValueCache
      unless predicateValueCache
        predicateValueCache = @convertValueForModifier value, modifier
        predicate.predicateValueCache = predicateValueCache

      attributeValue = @valueForAttributePath attributePath, item
      if attributeValue isnt undefined
        attributeValue = @convertValueForModifier attributeValue.toString(), modifier

      @evaluateRelation attributeValue, relation, predicateValueCache, predicate

  valueForAttributePath: (attributePath, item) ->
    attributeName = attributePath[0]
    attributeName = @options.attributeShortcuts?[attributeName] or attributeName
    switch attributeName
      when 'text'
        item.bodyString
      else
        item.getAttribute 'data-' + attributeName

  convertValueForModifier: (value, modifier) ->
    if modifier is 'i'
      value.toLowerCase()
    else if modifier is 'n'
      parseFloat(value)
    else if modifier is 'd'
      Date.parse(value) # weak
    else
      value # case insensitive is default

  evaluateRelation: (left, relation, right, predicate) ->
    switch relation
      when '='
        left is right
      when '!='
        left isnt right
      when '<'
        if left?
          left < right
        else
          false
      when '>'
        if left?
          left > right
        else
          false
      when '<='
        if left?
          left <= right
        else
          false
      when '>='
        if left?
          left >= right
        else
          false
      when 'beginswith'
        if left
          left.startsWith(right)
        else
          false
      when 'contains'
        if left
          left.indexOf(right) isnt -1
        else
          false
      when 'endswith'
        if left
          left.endsWith(right)
        else
          false
      when 'matches'
        if left?
          joinedValueRegexCache = predicate.joinedValueRegexCache
          if joinedValueRegexCache is undefined
            try
              joinedValueRegexCache = new RegExp(right.toString());
            catch error
              joinedValueRegexCache = null
            predicate.joinedValueRegexCache = joinedValueRegexCache

          if joinedValueRegexCache
            left.toString().match joinedValueRegexCache
          else
            false
        else
          false

  sliceResultsFrom: (slice, results, from) ->
    if slice
      length = results.length - from
      start = slice.start
      end = slice.end

      if length is 0
        return

      if end > length
        end = length

      if start isnt 0 or end isnt length
        sliced
        if start < 0
          start += length
          if start < 0
            start = 0
        if start > length - 1
          start = length - 1
        if end is null
          sliced = results[from + start]
        else
          if end < 0 then end += length
          if end < start then end = start
          sliced = results.slice(from).slice(start, end)

        Array.prototype.splice.apply(results, [from, results.length - from].concat(sliced));

  ###
  Section: AST To String
  ###

  predicateToString: (predicate, group) ->
    if predicate is '*'
      return '*'
    else
      openGroup = if group then '(' else ''
      closeGroup = if group then ')' else ''

      if andAST = predicate.and
        openGroup + @predicateToString(andAST[0], true) + ' and ' + @predicateToString(andAST[1], true) + closeGroup
      else if orAST = predicate.or
        openGroup + @predicateToString(orAST[0], true) + ' or ' + @predicateToString(orAST[1], true) + closeGroup
      else if notAST = predicate.not
        'not ' + @predicateToString notAST, true
      else
        result = []

        if attributePath = predicate.attributePath
          unless attributePath.length is 1 and attributePath[0] is 'text' #default
            result.push('@' + attributePath.join(':'))

        if relation = predicate.relation
          if relation isnt 'contains' #default
            result.push relation

        if modifier = predicate.modifier
          if modifier isnt 'i' #default
            result.push('[' + modifier + ']')

        if value = predicate.value
          try
            ItemPathParser.parse value,
              startRule: 'Value'
          catch error
            value = '"' + value + '"'
          result.push value

        result.join ' '

  stepToString: (step, first) ->
    predicate = @predicateToString step.predicate
    switch step.axis
      when 'child'
        predicate
      when 'descendant'
        if first
          predicate # default
        else
          '/' + predicate
      when 'parent'
        '..' + predicate
      else
        step.axis + '::' + predicate

  pathToString: (pathAST) ->
    stepStrings = []
    firstStep = null
    first = true
    for step in pathAST.steps
      unless firstStep
        firstStep = step
        stepStrings.push @stepToString step, true
      else
        stepStrings.push @stepToString step
    if pathAST.absolute and not (firstStep.axis is 'descendant')
      '/' + stepStrings.join('/')
    else
      stepStrings.join('/')

  pathExpressionToString: (itemPath, group) ->
    openGroup = if group then '(' else ''
    closeGroup = if group then ')' else ''
    if union = itemPath.union
      openGroup + @pathExpressionToString(union[0], true) + ' union ' + @pathExpressionToString(union[1], true) + closeGroup
    else if intersect = itemPath.intersect
      openGroup + @pathExpressionToString(intersect[0], true) + ' intersect ' + @pathExpressionToString(intersect[1], true) + closeGroup
    else if except = itemPath.except
      openGroup + @pathExpressionToString(except[0], true) + ' except ' + @pathExpressionToString(except[1], true) + closeGroup
    else
      @pathToString itemPath

  toString: ->
    return @pathExpressionToString @pathExpressionAST