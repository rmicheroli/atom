RegionStyleProperties = ['top', 'left', 'right', 'width', 'height']
SpaceRegex = /\s+/

module.exports =
class HighlightsComponent
  oldState: null

  constructor: ->
    @highlightNodesById = {}
    @regionNodesByHighlightId = {}

    @domNode = document.createElement('div')
    @domNode.classList.add('highlights')

    if atom.config.get('editor.useShadowDOM')
      insertionPoint = document.createElement('content')
      insertionPoint.setAttribute('select', '.underlayer')
      @domNode.appendChild(insertionPoint)

  getDomNode: ->
    @domNode

  updateSync: (state) ->
    newState = state.content.highlights
    @oldState ?= {}

    # remove highlights
    for id of @oldState
      unless newState[id]?
        @highlightNodesById[id].remove()
        delete @highlightNodesById[id]
        delete @regionNodesByHighlightId[id]
        delete @oldState[id]

    # add or update highlights
    for id, highlightState of newState
      unless @oldState[id]?
        highlightNode = document.createElement('div')
        highlightNode.classList.add('highlight')
        @highlightNodesById[id] = highlightNode
        @regionNodesByHighlightId[id] = {}
        @domNode.appendChild(highlightNode)
      @updateHighlightNode(id, highlightState)

    return

  updateHighlightNode: (id, newHighlightState) ->
    highlightNode = @highlightNodesById[id]
    oldHighlightState = (@oldState[id] ?= {regions: [], flashCount: 0})

    # update class
    if newHighlightState.class isnt oldHighlightState.class
      if oldHighlightState.class?
        if SpaceRegex.test(oldHighlightState.class)
          highlightNode.classList.remove(oldHighlightState.class.split(SpaceRegex)...)
        else
          highlightNode.classList.remove(oldHighlightState.class)

      if SpaceRegex.test(newHighlightState.class)
        highlightNode.classList.add(newHighlightState.class.split(SpaceRegex)...)
      else
        highlightNode.classList.add(newHighlightState.class)

      oldHighlightState.class = newHighlightState.class

    @updateHighlightRegions(id, newHighlightState)
    @flashHighlightNodeIfRequested(id, newHighlightState)

  updateHighlightRegions: (id, newHighlightState) ->
    oldHighlightState = @oldState[id]
    highlightNode = @highlightNodesById[id]

    # remove regions
    while oldHighlightState.regions.length > newHighlightState.regions.length
      oldHighlightState.regions.pop()
      @regionNodesByHighlightId[id][oldHighlightState.regions.length].remove()
      delete @regionNodesByHighlightId[id][oldHighlightState.regions.length]

    # add or update regions
    for newRegionState, i in newHighlightState.regions
      unless oldHighlightState.regions[i]?
        oldHighlightState.regions[i] = {}
        regionNode = document.createElement('div')
        regionNode.classList.add('region')
        regionNode.classList.add(newHighlightState.deprecatedRegionClass) if newHighlightState.deprecatedRegionClass?
        @regionNodesByHighlightId[id][i] = regionNode
        highlightNode.appendChild(regionNode)

      oldRegionState = oldHighlightState.regions[i]
      regionNode = @regionNodesByHighlightId[id][i]

      for property in RegionStyleProperties
        if newRegionState[property] isnt oldRegionState[property]
          oldRegionState[property] = newRegionState[property]
          if newRegionState[property]?
            regionNode.style[property] = newRegionState[property] + 'px'
          else
            regionNode.style[property] = ''

    return

  flashHighlightNodeIfRequested: (id, newHighlightState) ->
    oldHighlightState = @oldState[id]
    return unless newHighlightState.flashCount > oldHighlightState.flashCount

    highlightNode = @highlightNodesById[id]

    addFlashClass = =>
      highlightNode.classList.add(newHighlightState.flashClass)
      oldHighlightState.flashClass = newHighlightState.flashClass
      @flashTimeoutId = setTimeout(removeFlashClass, newHighlightState.flashDuration)

    removeFlashClass = =>
      highlightNode.classList.remove(oldHighlightState.flashClass)
      oldHighlightState.flashClass = null
      clearTimeout(@flashTimeoutId)

    if oldHighlightState.flashClass?
      removeFlashClass()
      requestAnimationFrame(addFlashClass)
    else
      addFlashClass()

    oldHighlightState.flashCount = newHighlightState.flashCount
