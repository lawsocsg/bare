---
# Jekyll front matter needed to trigger coffee compilation
---

# Programmatically add the search box to the site
# This allows the search box to be hidden if javascript is disabled
siteNavElement = document.getElementsByClassName("site-nav")[0]
siteSearchElement = document.createElement("div");
siteSearchElement.classList.add("site-search")
searchBoxElement = document.createElement("input");
searchBoxElement.id = "search-box";
searchBoxElement.setAttribute("type", "text");
searchBoxElement.setAttribute("placeholder", "Building search index...");
searchBoxElement.setAttribute("disabled", "");
siteSearchElement.prepend(searchBoxElement);
siteNavElement.prepend(siteSearchElement);


# The main "blob" of site data constructed by liquid
# We cherry pick to minimize size
# Also because jsonify doesn't work quite right and collapses the page objects
# into just strings when we jsonify the whole site
site = 
  title: {{ site.title | jsonify }}
  url: {{ site.url | jsonify }}
  
pages = [
  {% for site_page in site.html_pages %}
    {
      "title": {{ site_page.title | jsonify }},
      # For consistency all page markdown is converted to HTML
      {% if site_page.url == page.url %}
      "content": {{ site_page.content | jsonify }},
      {% else %}
      "content": {{ site_page.content | markdownify | jsonify }},
      {% endif %}
      "url": {{ site_page.url | jsonify }}
    }
  {% endfor %}
]


# Helper function which returns a flat list of header and text nodes
HEADER_TAGS = ["H1", "H2", "H3", "H4", "H5", "H6"]
getHeadersAndText = (root)->
  walker = document.createTreeWalker(
    root
    NodeFilter.SHOW_ALL
    acceptNode: (node)-> 
      # Grab header tags for building a table of contents
      if HEADER_TAGS.indexOf(node.tagName) >= 0
        return NodeFilter.FILTER_ACCEPT
      # Reject the immediate children of header tags
      # Since they are already included under their parent
      if HEADER_TAGS.indexOf(node.parentNode.tagName) >= 0
        return NodeFilter.FILTER_REJECT
      # Add basic text nodes inbetween headers
      if node.nodeType is 3 then return NodeFilter.FILTER_ACCEPT
      # Skip everything else
      return NodeFilter.FILTER_SKIP
    false
  )
  nodes = []
  while node = walker.nextNode() then nodes.push node
  return nodes


# Build a site hierarchy tree of nested sections
# Each section has a representative component
# An array of its own text
# and an array of subsections
siteHierarchy = {
  component: site
  title: site.title
  url: site.url
  text: []
}
# Parse page html and build a section hierarchy per page
siteHierarchy.subsections = pages.map (page) ->
  body = new DOMParser().parseFromString(page.content, 'text/html').body
  headersAndText = getHeadersAndText(body)
  root = 
    parent: siteHierarchy
    component: page
    title: page.title
    url: page.url
    text: []
    subsections: []
  # Iterate through the html nodes and build the section tree depth first 
  currentSection = root
  headersAndText.forEach (node) ->
    # Text nodes get added under the current header
    if HEADER_TAGS.indexOf(node.tagName) < 0
      currentSection.text.push node.textContent
      return
    # If you're bigger then climb the tree till you're not
    # Then add yourself and drill down 
    # #lifeprotips
    while (
      HEADER_TAGS.indexOf(node.tagName) <= 
      HEADER_TAGS.indexOf(currentSection.component.tagName)
    ) then currentSection = currentSection.parent
    newSection = 
      parent: currentSection
      component: node
      title: node.textContent
      url: page.url + "#" + node.id
      text: []
      subsections: []
    currentSection.subsections.push newSection
    currentSection = newSection
  return root

# A flat list of sections and their associated text
siteSections = {}
queue = [siteHierarchy]
while queue.length > 0
  section = queue.pop()
  queue.push.apply(queue, section.subsections.reverse())
  siteSections[section.url] = section
Object.values(siteSections).forEach (section) -> 
  section.component = null
Object.values(siteSections).forEach (section) -> 
  section.text = section.text.join('')

# Asynchronously build the search index
searchIndexPromise = new Promise (resolve, reject) ->
  worker = new Worker "/assets/worker.js"
  worker.onmessage = (event) ->
    worker.terminate()
    resolve lunr.Index.load event.data
  worker.onerror = (error) ->
    Promise.reject(error)
  worker.postMessage Object.values(siteSections)


# Turns lunr search results into a simple {title, description, link} array
snippetSpace = 40
maxSnippets = 4
maxResults = 10
translateLunrResults = (lunrResults) ->
  lunrResults.slice(0, maxResults);
  lunrResults.map (result) ->
    matchedDocument = siteSections[result.ref]
    snippets = [];
    # Loop over matching terms
    for term of result.matchData.metadata
      # Loop over the matching fields for each term
      fields = result.matchData.metadata[term]
      for field of fields
        positions = fields[field].position
        positions = positions.slice(0, 1)
        # Loop over the position within each field
        for positionIndex of positions
          position = positions[positionIndex]
          # Add to the description the snippet for that match
          preMatch = matchedDocument[field].substring(
            position[0] - snippetSpace, 
            position[0]
          )
          match = matchedDocument[field].substring(
            position[0], 
            position[0] + position[1]
          )
          postMatch = matchedDocument[field].substring(
            position[0] + position[1], 
            position[0] + position[1] + snippetSpace
          )
          snippet = '...' + preMatch + '<strong>' + match + '</strong>' + postMatch + '...  '
          snippets.push snippet
          if (snippets.length >= maxSnippets) then break
        if (snippets.length >= maxSnippets) then break
      if (snippets.length >= maxSnippets) then break
    # Build a simple flat object per lunr result
    {
      title: matchedDocument.title
      description: snippets.join('');
      url: matchedDocument.url
    }


# Displays the search results in HTML
# Takes an array of objects with "title" and "description" properties
renderSearchResults = (searchResults) ->
  container = document.getElementsByClassName('search-results')[0]
  container.innerHTML = ''
  searchResults.forEach (result) ->
    element = document.createElement('a')
    element.classList.add 'nav-link'
    element.setAttribute 'href', result.url
    element.innerHTML = result.title
    description = document.createElement('p')
    description.innerHTML = result.description
    element.appendChild description
    container.appendChild element
    return
  return


# Enable the searchbox once the index is built
searchIndexPromise.then (searchIndex) ->
  searchBoxElement.removeAttribute "disabled"
  searchBoxElement.setAttribute "placeholder", "Type here to search..."
  searchBoxElement.addEventListener 'input', (event) ->
    toc = document.getElementsByClassName('table-of-contents')[0]
    searchResults = document.getElementsByClassName('search-results')[0]
    query = searchBoxElement.value
    if query.length == 0
      searchResults.setAttribute 'hidden', true
      toc.removeAttribute 'hidden'
    else
      toc.setAttribute 'hidden', ''
      searchResults.removeAttribute 'hidden'
      lunrResults = searchIndex.search(query+"*")
      results = translateLunrResults(lunrResults)
      renderSearchResults results
