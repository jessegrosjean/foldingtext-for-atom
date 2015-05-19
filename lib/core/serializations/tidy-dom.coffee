tidy = (element, indent) ->
  if element.tagName is 'P'
    return

  eachChild = element.firstElementChild
  if eachChild
    childIndent = indent + '  '
    while eachChild
      tagName = eachChild.tagName
      if tagName is 'UL' and not eachChild.firstElementChild
        ref = eachChild
        eachChild = eachChild.nextElementSibling
        element.removeChild ref
      else
        tidy eachChild, childIndent
        element.insertBefore element.ownerDocument.createTextNode(childIndent), eachChild
        eachChild = eachChild.nextElementSibling
    element.appendChild element.ownerDocument.createTextNode(indent)

module.exports = tidy
