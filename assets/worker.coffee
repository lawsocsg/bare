---
# Jekyll front matter needed to trigger coffee compilation
---
# Web worker used to building the search index outside the main thread

importScripts "/assets/lunr.js"
console.log "Worker initialized"
@onmessage = (event) => 
  console.log "Starting to build index"
  pages = event.data
  index = lunr ->
    @ref 'url'
    @field 'title', boost: 10
    @field 'text'
    @metadataWhitelist = ['position']
    pages.forEach (page) =>
      @add
        'url': page.url
        'title': page.title
        'text': page.text
  console.log "Done build index"
  @postMessage index.toJSON()


