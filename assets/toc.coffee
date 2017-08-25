---
# Jekyll front matter needed to trigger coffee compilation
---
# Build table of contents
HEADER_TAGS = [
  'H1'
  'H2'
  'H3'
  'H4'
  'H5'
  'H6'
]
siteHierarchy = pages.map((page) ->
  doc = (new DOMParser).parseFromString(page.content, 'text/html')
  headers = doc.querySelectorAll(HEADER_TAGS.join(','))
  root = 
    value: page
    children: []
  currentNode = root
  Array.from(headers).forEach (element) ->
    if HEADER_TAGS.indexOf(element.tagName) < 0
      return
    # If you're bigger then climb the tree till you're not
    # Then add yourself and drill down
    while HEADER_TAGS.indexOf(element.tagName) <= HEADER_TAGS.indexOf(currentNode.value.tagName)
      currentNode = currentNode.parent
    newNode = 
      parent: currentNode
      value: element
      children: []
    currentNode.children.push newNode
    currentNode = newNode
    return
  root
)
# Merge redundant internal nodes

contractTree = (tree) ->
  queue = [ tree ]
  while queue.length > 0
    currentNode = queue.shift()
    # Contract 
    while currentNode.children.length == 1
      currentNode.children = currentNode.children[0].children
      currentNode.children.forEach (child) ->
        child.parent = currentNode
        return
    queue.push.apply queue, currentNode.children
  tree

siteHierarchy =         
  value: {{ site | jsonify }}
  children: siteHierarchy
siteHierarchy = contractTree(siteHierarchy)
