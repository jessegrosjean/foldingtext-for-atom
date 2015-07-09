module.exports =
class Point

  row: null
  column: null

  ###
  Section: Construction
  ###

  @fromObject: (object, copy) ->
    if object instanceof Point
      if copy then object.copy() else object
    else
      if Array.isArray(object)
        [row, column] = object
      else
        { row, column } = object

      new Point(row, column)

  ###
  Section: Comparison
  ###

  @min: (point1, point2) ->
    point1 = @fromObject(point1)
    point2 = @fromObject(point2)
    if point1.isLessThanOrEqual(point2)
      point1
    else
      point2

  @max: (point1, point2) ->
    point1 = Point.fromObject(point1)
    point2 = Point.fromObject(point2)
    if point1.compare(point2) >= 0
      point1
    else
      point2

  @assertValid: (point) ->
    unless isNumber(point.row) and isNumber(point.column)
      throw new TypeError("Invalid Point: #{point}")

  @ZERO: Object.freeze(new Point(0, 0))

  @INFINITY: Object.freeze(new Point(Infinity, Infinity))

  ###
  Section: Construction
  ###

  constructor: (row=0, column=0) ->
    unless this instanceof Point
      return new Point(row, column)
    @row = row
    @column = column

  copy: ->
    new Point(@row, @column)

  negate: ->
    new Point(-@row, -@column)

  ###
  Section: Operations
  ###

  freeze: ->
    Object.freeze(this)

  translate: (other) ->
    {row, column} = Point.fromObject(other)
    new Point(@row + row, @column + column)

  traverse: (other) ->
    other = Point.fromObject(other)
    row = @row + other.row
    if other.row is 0
      column = @column + other.column
    else
      column = other.column

    new Point(row, column)

  traversalFrom: (other) ->
    other = Point.fromObject(other)
    if @row is other.row
      if @column is Infinity and other.column is Infinity
        new Point(0, 0)
      else
        new Point(0, @column - other.column)
    else
      new Point(@row - other.row, @column)

  splitAt: (column) ->
    if @row is 0
      rightColumn = @column - column
    else
      rightColumn = @column

    [new Point(0, column), new Point(@row, rightColumn)]

  ###
  Section: Comparison
  ###

  compare: (other) ->
    other = Point.fromObject(other)
    if @row > other.row
      1
    else if @row < other.row
      -1
    else
      if @column > other.column
        1
      else if @column < other.column
        -1
      else
        0

  isEqual: (other) ->
    return false unless other
    other = Point.fromObject(other)
    @row is other.row and @column is other.column

  isLessThan: (other) ->
    @compare(other) < 0

  isLessThanOrEqual: (other) ->
    @compare(other) <= 0

  isGreaterThan: (other) ->
    @compare(other) > 0

  isGreaterThanOrEqual: (other) ->
    @compare(other) >= 0

  isZero: ->
    @row is 0 and @column is 0

  isPositive: ->
    if @row > 0
      true
    else if @row < 0
      false
    else
      @column > 0

  isNegative: ->
    if @row < 0
      true
    else if @row > 0
      false
    else
      @column < 0

  ###
  Section: Conversion
  ###

  toArray: ->
    [@row, @column]

  toString: ->
    "(#{@row}, #{@column})"

isNumber = (value) ->
  (typeof value is 'number') and (not Number.isNaN(value))