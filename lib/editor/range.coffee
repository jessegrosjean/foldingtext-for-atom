{newlineRegex} = require './helpers'
Point = require './point'

module.exports =
class Range

  start: null
  end: null

  ###
  Section: Construction
  ###

  @fromObject: (object, copy) ->
    if Array.isArray(object)
      new this(object[0], object[1])
    else if object instanceof this
      if copy then object.copy() else object
    else
      new this(object.start, object.end)

  @fromText: (args...) ->
    if args.length > 1
      startPoint = Point.fromObject(args.shift())
    else
      startPoint = new Point(0, 0)
    text = args.shift()
    endPoint = startPoint.copy()
    lines = text.split(newlineRegex)
    if lines.length > 1
      lastIndex = lines.length - 1
      endPoint.row += lastIndex
      endPoint.column = lines[lastIndex].length
    else
      endPoint.column += lines[0].length
    new this(startPoint, endPoint)

  @fromPointWithDelta: (startPoint, rowDelta, columnDelta) ->
    startPoint = Point.fromObject(startPoint)
    endPoint = new Point(startPoint.row + rowDelta, startPoint.column + columnDelta)
    new this(startPoint, endPoint)

  constructor: (pointA = new Point(0, 0), pointB = new Point(0, 0)) ->
    unless this instanceof Range
      return new Range(pointA, pointB)

    pointA = Point.fromObject(pointA)
    pointB = Point.fromObject(pointB)

    if pointA.isLessThanOrEqual(pointB)
      @start = pointA
      @end = pointB
    else
      @start = pointB
      @end = pointA

  copy: ->
    new @constructor(@start.copy(), @end.copy())

  negate: ->
    new @constructor(@start.negate(), @end.negate())

  ###
  Section: Range Details
  ###

  isEmpty: ->
    @start.isEqual(@end)

  isSingleLine: ->
    @start.row is @end.row

  getLineCount: ->
    @end.row - @start.row + 1

  getRows: ->
    [@start.row..@end.row]

  ###
  Section: Operations
  ###

  freeze: ->
    @start.freeze()
    @end.freeze()
    Object.freeze(this)

  union: (otherRange) ->
    start = if @start.isLessThan(otherRange.start) then @start else otherRange.start
    end = if @end.isGreaterThan(otherRange.end) then @end else otherRange.end
    new @constructor(start, end)

  translate: (startDelta, endDelta=startDelta) ->
    new @constructor(@start.translate(startDelta), @end.translate(endDelta))

  traverse: (delta) ->
    new @constructor(@start.traverse(delta), @end.traverse(delta))

  ###
  Section: Comparison
  ###

  compare: (other) ->
    other = @constructor.fromObject(other)
    if value = @start.compare(other.start)
      value
    else
      other.end.compare(@end)

  isEqual: (other) ->
    return false unless other?
    other = @constructor.fromObject(other)
    other.start.isEqual(@start) and other.end.isEqual(@end)

  coversSameRows: (other) ->
    @start.row is other.start.row and @end.row is other.end.row

  intersectsWith: (otherRange, exclusive) ->
    if exclusive
      not (@end.isLessThanOrEqual(otherRange.start) or @start.isGreaterThanOrEqual(otherRange.end))
    else
      not (@end.isLessThan(otherRange.start) or @start.isGreaterThan(otherRange.end))

  containsRange: (otherRange, exclusive) ->
    {start, end} = @constructor.fromObject(otherRange)
    @containsPoint(start, exclusive) and @containsPoint(end, exclusive)

  containsPoint: (point, exclusive) ->
    point = Point.fromObject(point)
    if exclusive
      point.isGreaterThan(@start) and point.isLessThan(@end)
    else
      point.isGreaterThanOrEqual(@start) and point.isLessThanOrEqual(@end)

  intersectsRow: (row) ->
    @start.row <= row <= @end.row

  intersectsRowRange: (startRow, endRow) ->
    [startRow, endRow] = [endRow, startRow] if startRow > endRow
    @end.row >= startRow and endRow >= @start.row

  getExtent: ->
    @end.traversalFrom(@start)

  ###
  Section: Conversion
  ###

  toDelta: ->
    rows = @end.row - @start.row
    if rows is 0
      columns = @end.column - @start.column
    else
      columns = @end.column
    new Point(rows, columns)

  toString: ->
    "[#{@start} - #{@end}]"