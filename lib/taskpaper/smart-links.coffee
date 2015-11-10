emailRegex = /\b[A-Z0-9\._%+\-]+@[A-Z0-9\.\-]+\.[A-Z]{2,4}\b/gi
webRegex = /\b(?:([a-z][\w\-]+:(?:\/{1,3}|[a-z0-9%])|www\d{0,3}[.])(?:[^\s()<>]+|\([^\s()<>]+\))+(?:\([^\s()<>]+\)|[^`!()\[\]{};:'".,<>?«»“”‘’\s]))/gi

highlightLinks = (item) ->
  bodyString = item.bodyString

  # Email
  if bodyString.indexOf('@') isnt -1
    while match = emailRegex.exec(bodyString)
      linkIndex = match.index
      linkText = bodyString.substring(linkIndex, linkIndex + match[0].length)
      # Skip if scheme, will be caught by URL parse
      unless bodyString[linkIndex - 1] is ':'
        item.addBodyHighlightAttributesInRange(url: 'mailto:' + linkText, linkIndex, linkText.length)

  # URLS
  while match = webRegex.exec(bodyString)
    linkIndex = match.index
    linkText = bodyString.substring(linkIndex, linkIndex + match[0].length)
    linkTarget = linkText
    if linkText.indexOf('www') is 0
      linkTarget = 'http://' + linkText
    item.addBodyHighlightAttributesInRange(url: linkTarget, linkIndex, linkText.length)

module.exports =
  highlightLinks: highlightLinks
