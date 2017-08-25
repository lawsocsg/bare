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

# The main "blob" of the site page information constructed by liquid
pages = [
  {% for site_page in site.html_pages %}
    {
      "title": {{ site_page.title | jsonify }},
      {% if site_page.url == page.url %}
      "content": {{ site_page.content | jsonify }},
      "text": {{ site_page.content | strip_html | strip_newlines | jsonify }},
      {% else %}
      "content": {{ site_page.content | markdownify | jsonify }},
      "text": {{ site_page.content | markdownify | strip_html | strip_newlines | jsonify }},
      {% endif %}
      "url": {{ site_page.url | jsonify }}
    }
  {% endfor %}
]
pageUrlIndex = {}
pages.forEach (page) ->
  pageUrlIndex[page.url] = page

# Asynchronously build the search index
searchIndexPromise = new Promise (resolve, reject) ->
  worker = new Worker "/assets/worker.js"
  worker.onmessage = (event) ->
    worker.terminate()
    resolve lunr.Index.load event.data
  worker.onerror = (error) ->
    Promise.reject(error)
  worker.postMessage pages


# Turns lunr search results into a simple {title, description, link} array
snippetSpace = 40
maxSnippets = 4
maxResults = 10
translateLunrResults = (lunrResults) ->
  lunrResults.slice(0, maxResults);
  lunrResults.map (result) ->
    matchingPage = pageUrlIndex[result.ref]
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
          preMatch = matchingPage[field].substring(
            position[0] - snippetSpace, 
            position[0]
          )
          match = matchingPage[field].substring(
            position[0], 
            position[0] + position[1]
          )
          postMatch = matchingPage[field].substring(
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
      title: matchingPage.title
      description: snippets.join('');
      url: matchingPage.url
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
