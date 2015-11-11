// Copyright (c) 2015 Jesse Grosjean. All rights reserved.
//
// To generate item-path-parser.js:
//   $ pegjs --cache  --allowed-start-rules ItemPathExpression,Value item-path-parser.pegjs

{
  var reservedWords = {
    'union': true,
    'except': true,
    'intersect': true,
    'and': true,
    'or': true,
    'not': true
  }

  function combine(left, right, label) {
    if (right) {
      var result = {};
      result[label] = [left, right];
      return result;
    } else {
      return left;
    }
  }

  var keywords = [];

  function keywordCompare(a, b) {
    var aOffset = a.offset
    var bOffset = b.offset

    if (aOffset !== bOffset) {
      return aOffset - bOffset;
    } else if (a.text.length !== b.text.length) {
      return a.text.length - b.text.length;
    } else if (a.label !== b.label) {
      if (a < b) {
        return -1;
      } else {
        return 1;
      }
    } else {
      return 0;
    }
  }

  function keyword(label, textValue) {
    textValue = textValue === undefined ? text() : textValue;

    var offsetValue = location().start.offset;
    var length = keywords.length - 1;
    while (length >= 0 && keywords[length].offset === offsetValue) {
      keywords.pop();
      length--;
    }

    keywords.push({
      label: label,
      offset : offsetValue,
      text : textValue
    });

    keywords.sort(keywordCompare);
  }
}

ItemPathExpression
  = paths:UnionPaths _ {
    paths.keywords = keywords;
    return paths;
  }

UnionPaths
  = left:ExceptPaths _ UnionKeyword _ right:UnionPaths { return combine(left, right, 'union') }
  / ExceptPaths

UnionKeyword
  = union:'union' {
    keyword('keyword.set');
    return union;
  }

ExceptPaths
  = left:IntersectPaths _ ExceptKeyword _ right:ExceptPaths { return combine(left, right, 'except') }
  / IntersectPaths

ExceptKeyword
  = except:'except' {
    keyword('keyword.set');
    return except;
  }

IntersectPaths
  = left:PathExpression _ IntersectKeyword _ right:IntersectPaths { return combine(left, right, 'intersect') }
  / PathExpression

IntersectKeyword
  = intersect:'intersect' {
    keyword('keyword.set');
    return intersect;
  }

Slice
  = '[' start:Integer end:SliceEnd? ']' {
    return {
      start: start === null ? 0 : start,
      end: end
    }
  }

SliceEnd
  = ':' integer:Integer? {
    if (integer !== null) {
      return integer;
    }
    return Number.MAX_VALUE;
  }

Integer
  = sign:'-'? number:[0-9]+ {
    if (sign) {
      return -parseInt(number.join(''), 10);
    } else {
      return parseInt(number.join(''), 10);
    }
  }

PathExpression
  = !OrPredicates '(' _ expression:UnionPaths _ ')' slice:Slice? {
    expression.slice = slice;
    return expression;
  }
  / ItemPath

ItemPath
  = absolute:'/'? step:PathStep trailingSteps:ItemPathTrailingStep* {
    absolute = !! absolute;

    if (absolute) {
      keyword('entity.other.axis', '/');
    } else if (step.axis === 'child') {
      // Default to descendent axis for non absolute paths.
      step.axis = 'descendant';
    }

    var steps = [step];
    if (trailingSteps) {
       steps = steps.concat(trailingSteps);
    }
    return {
      absolute : absolute,
      steps : steps
    }
  }

PathStep
  = axis:PathStepAxis? type:PathStepType? predicate:OrPredicates? slice:Slice? & {
    return type || predicate;
  } {
    if (!axis) {
      axis = 'child';
    }

    if (!type) {
      type = '*';
    }

    if (!predicate) {
      predicate = '*'
    }

    return {
      axis : axis,
      type : type,
      predicate : predicate,
      slice: slice
    }
  }

PathStepAxis
  = axis:(
      'ancestor-or-self::'
    / 'ancestor::'
    / 'child::'
    / 'descendant-or-self::'
    / 'descendant::'
    / 'following-sibling::'
    / 'following::'
    / 'preceding-sibling::'
    / 'preceding::'
    / 'parent::'
    / 'self::'
    // shortcuts
    / '/'
    / '..'
    ) {
      keyword('entity.other.axis');

      switch(axis) {
      case '/':
        return 'descendant';
      case '..':
        return 'parent';
      default:
        return axis.substr(0, axis.length - 2);
      }
    }

PathStepType
  = name:Name & {
    var types = options.types;
    return types && types[name];
  } _ {
    keyword('entity.other.axis');
    return name;
  }

ItemPathTrailingStep
  = '/' step:PathStep {
    keyword('entity.other.axis', '/');
    return step;
  }

OrPredicates
  = left:AndPredicates _ OrKeyword _ right:OrPredicates { return combine(left, right, 'or') }
  / AndPredicates

OrKeyword
  = or:'or' {
    keyword('keyword.boolean');
    return or;
  }

AndPredicates
  = left:NotPredicate _ AndKeyword _ right:AndPredicates { return combine(left, right, 'and') }
  / NotPredicate

AndKeyword
  = and:'and' {
    keyword('keyword.boolean');
    return and;
  }

NotPredicate
  = not:(NotKeyword whitespace+)* expression:PredicateExpression {
    if (not && (not.length % 2)) {
      return {
        not : expression
      };
    } else {
      return expression;
    }
  }

NotKeyword
  = not:'not' {
    keyword('keyword.boolean');
    return not;
  }

PredicateExpression
  = '(' _ expression:OrPredicates _ ')' { return expression; }
  / Predicate

Predicate
  = '*'
  / attributePath:AttributePath? _ relation:Relation? _ modifier:Modifier? _ value:Value {
    return {
      attributePath : attributePath || ['text'],
      relation : relation || 'contains',
      modifier : modifier || 'i',
      value : value
    }
  }
  / attributePath:AttributePath {
    return {
      attributePath : attributePath,
      relation : null,
      value : null
    }
  }

AttributePath
  = '@' name:AttributePathSegmentName trailingSegments:(AttributePathSegment)* {
    var segments = [name];
    if (trailingSegments) {
      segments = segments.concat(trailingSegments);
    }
    keyword('entity.other.attribute-name');
    return segments;
  }

AttributePathSegment
  = ':' name:AttributePathSegmentName {
    return name;
  }

AttributePathSegmentName
  = chars:(AttributePathSegmentNameChar)+ {
    return chars.join('');
  }

AttributePathSegmentNameChar
  = !':' char:NameChar { return char; }

Relation
  = relation:('beginswith'
  / 'contains'
  / 'endswith'
  / 'like'
  / 'matches'
  / '='
  / '!='
  / '<='
  / '>='
  / '<'
  / '>') {
    keyword('keyword.operator.relation');
    return relation;
  }

Modifier
  = '[' modifier:('s' / 'i' / 'n' / 'd') ']' {
    keyword('keyword.operator.modifier');
    return modifier;
  }

Value
  = strings:( _ string:(QuotedString / UnquotedString) _ )+ {
    var results = [];
    for (var i = 0; i < strings.length; i++) {
      results.push(strings[i].join(''));
    }
    return results.join('').trim();
  }

QuotedString "string"
  = '"' '"' _             { return "";    }
  / '"' chars:Chars '"' {
    keyword('string.quoted');
    return chars;
  }

Chars
  = chars:Char+ { return chars.join(""); }

Char
  = [^"\\\0-\x1F\x7f]
  / '\\"'  { return '"';  }
  / "\\\\" { return "\\"; }
  / "\\/"  { return "/";  }
  / "\\b"  { return "\b"; }
  / "\\f"  { return "\f"; }
  / "\\n"  { return "\n"; }
  / "\\r"  { return "\r"; }
  / "\\t"  { return "\t"; }

UnquotedString "string"
  = string:([0-9] / [~`!#$%^&*-+=\{\}|\\;',.?-] / Name) ! {
    return reservedWords[string];
  } {
    keyword('string.unquoted');
    return string;
  }

// http://www.w3.org/TR/REC-xml/#NT-Name

NameStartChar
  = ':'
  / [A-Z]
  / '_'
  / [a-z]
  / [\u00C0-\u00D6]
  / [\u00D8-\u00F6]
  / [\u00F8-\u02FF]
  / [\u0370-\u037D]
  / [\u037F-\u1FFF]
  / [\u200C-\u200D]
  / [\u2070-\u218F]
  / [\u2C00-\u2FEF]
  / [\u3001-\uD7FF]
  / [\uF900-\uFDCF]
  / [\uFDF0-\uFFFD]

NameChar
  = NameStartChar
  / '-'
  / '.'
  / [0-9]
  / [\u00B7]
  / [\u0300-\u036F]
  / [\u203F-\u2040]

Name
  = startchar:NameStartChar chars:(NameChar)* {
    return startchar + chars.join('');
  }

_ "whitespace"
  = whitespace:whitespace* { return whitespace.join("") }

whitespace
  = [ \t\n\r]
