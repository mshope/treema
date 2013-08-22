do __init = ->
  
  TreemaNode.setNodeSubclass 'string', class StringNode extends TreemaNode
    valueClass: 'treema-string'
    getDefaultValue: -> ''
    @inputTypes = ['color', 'date', 'datetime', 'datetime-local',
                   'email', 'month', 'range', 'search',
                   'tel', 'text', 'time', 'url', 'week']
  
    buildValueForDisplay: (valEl) -> @buildValueForDisplaySimply(valEl, "\"#{@data}\"")
  
    buildValueForEditing: (valEl) ->
      input = @buildValueForEditingSimply(valEl, @data)
      input.attr('maxlength', @schema.maxLength) if @schema.maxLength
      input.attr('type', @schema.format) if @schema.format in StringNode.inputTypes
  
    saveChanges: (valEl) -> @data = $('input', valEl).val()



  TreemaNode.setNodeSubclass 'number', class NumberNode extends TreemaNode
    valueClass: 'treema-number'
    getDefaultValue: -> 0
  
    buildValueForDisplay: (valEl) -> @buildValueForDisplaySimply(valEl, JSON.stringify(@data))
  
    buildValueForEditing: (valEl) ->
      input = @buildValueForEditingSimply(valEl, JSON.stringify(@data), 'number')
      input.attr('max', @schema.maximum) if @schema.maximum
      input.attr('min', @schema.minimum) if @schema.minimum
  
    saveChanges: (valEl) -> @data = parseFloat($('input', valEl).val())



  TreemaNode.setNodeSubclass 'null', NullNode = class NullNode extends TreemaNode
    valueClass: 'treema-null'
    editable: false
    buildValueForDisplay: (valEl) -> @buildValueForDisplaySimply(valEl, 'null')



  TreemaNode.setNodeSubclass 'boolean', class BooleanNode extends TreemaNode
    valueClass: 'treema-boolean'
    getDefaultValue: -> false
  
    buildValueForDisplay: (valEl) -> @buildValueForDisplaySimply(valEl, JSON.stringify(@data))
  
    buildValueForEditing: (valEl) ->
      input = @buildValueForEditingSimply(valEl, JSON.stringify(@data))
      $('<span></span>').text(JSON.stringify(@data)).insertBefore(input)
      input.focus()
  
    toggleValue: (newValue=null) ->
      @data = not @data
      @data = newValue if newValue?
      valEl = @getValEl().empty()
      if @isDisplaying() then @buildValueForDisplay(valEl) else @buildValueForEditing(valEl)
  
    onSpacePressed: -> @toggleValue()
    onFPressed: -> @toggleValue(false)
    onTPressed: -> @toggleValue(true)
    saveChanges: ->



  TreemaNode.setNodeSubclass 'array', class ArrayNode extends TreemaNode
    valueClass: 'treema-array'
    getDefaultValue: -> []
    collection: true
    ordered: true
    directlyEditable: false
  
    getChildren: -> ([key, value, @getChildSchema()] for value, key in @data)
    getChildSchema: -> @schema.items or {}
    buildValueForDisplay: (valEl) ->
      text = []
      return unless @data
      for child in @data[..2]
        helperTreema = TreemaNode.make(null, {schema: @getChildSchema(), data:child}, @)
        val = $('<div></div>')
        helperTreema.buildValueForDisplay(val)
        text.push(val.text())
      text.push('...') if @data.length > 3
  
      @buildValueForDisplaySimply(valEl, text.join(', '))
  
    buildValueForEditing: (valEl) -> @buildValueForEditingSimply(valEl, JSON.stringify(@data))
  
    canAddChild: ->
      return false if @schema.additionalItems is false and @data.length >= @schema.items.length
      return false if @schema.maxItems? and @data.length >= @schema.maxItems
      return true
  
    addNewChild: ->
      return unless @canAddChild()
      @open() if @isClosed()
      new_index = Object.keys(@childrenTreemas).length
      schema = @getChildSchema()
      newTreema = @addChildTreema(new_index, undefined, schema)
      newTreema.justAdded = true
      newTreema.tv4 = @tv4
      childNode = @createChildNode(newTreema)
      @getAddButtonEl().before(childNode)
      newTreema.edit()
      true



  TreemaNode.setNodeSubclass 'object', class ObjectNode extends TreemaNode
    valueClass: 'treema-object'
    getDefaultValue: ->
      d = {}
      return d unless @schema?.properties
      for childKey, childSchema of @schema.properties
        d[childKey] = childSchema.default if childSchema.default
      d

    collection: true
    keyed: true
    newPropertyTemplate: '<input class="treema-new-prop" />'
    directlyEditable: false
  
    getChildren: ->
      # order based on properties object first
      children = []
      keysAccountedFor = []
      if @schema.properties
        for key of @schema.properties
          continue if typeof @data[key] is 'undefined'
          keysAccountedFor.push(key)
          children.push([key, @data[key], @getChildSchema(key)])
  
      for key, value of @data
        continue if key in keysAccountedFor
        children.push([key, value, @getChildSchema(key)])
      children
  
    getChildSchema: (key_or_title) ->
      for key, child_schema of @schema.properties
        return child_schema if key is key_or_title or child_schema.title is key_or_title
      {}
  
    buildValueForDisplay: (valEl) ->
      text = []
      return unless @data
      skipped = []
      for key, value of @data
        if @schema.displayProperty? and key isnt @schema.displayProperty
          skipped.push(key)
          continue
          
        helperTreema = TreemaNode.make(null, {schema: @getChildSchema(key), data:value}, @)
        val = $('<div></div>')
        helperTreema.buildValueForDisplay(val)
        text.push(val.text())
      @buildValueForDisplaySimply(valEl, '{' + text.join(', ') + '}')
      
    buildValueForEditing: (valEl) -> @buildValueForEditingSimply(valEl, JSON.stringify(@data))
  
    populateData: ->
      super()
      return unless @schema.required
      for key in @schema.required
        continue if @data[key]
        helperTreema = TreemaNode.make(null, {schema: @getChildSchema(key), data:null}, @)
        helperTreema.populateData()
        @data[key] = helperTreema.data
  
    canAddChild: ->
      return false if @schema.maxProperties? and Object.keys(@data).length >= @schema.maxProperties
      return true if @schema.additionalProperties is false
      return true if @schema.patternProperties?
      return true if @childPropertiesAvailable().length
      return false
  
    canAddProperty: (key) ->
      return true unless @schema.additionalProperties is false
      return true if @schema.properties[key]?
      if @schema.patternProperties?
        return true if RegExp(pattern).test(key) for pattern of @schema.patternProperties
      return false
  
    addNewChild: ->
      return unless @canAddChild()
      properties = @childPropertiesAvailable()
      keyInput = $(@newPropertyTemplate)
      keyInput.autocomplete?(source: properties, minLength: 0, delay: 0, autoFocus: true)
      @getAddButtonEl().before(keyInput)
      keyInput.focus()
      keyInput.blur @onNewPropertyBlur
      keyInput.autocomplete('search')
      true
  
    addingNewProperty: -> document.activeElement is @$el.find('.treema-new-prop')[0]
  
    onNewPropertyBlur: (e) =>
      keyInput = $(e.target)
      @clearTemporaryErrors()
      key = @getPropertyKey(keyInput)
      return @showBadPropertyError(keyInput) if key.length and not @canAddProperty(key)
      keyInput.remove()
      return unless key.length
      return @childrenTreemas[key].toggleEdit() if @childrenTreemas[key]?
      @addNewChildForKey(key)
  
    getPropertyKey: (keyInput) ->
      key = keyInput.val()
      if @schema.properties
        for child_key, child_schema of @schema.properties
          key = child_key if child_schema.title is key
      key
  
    showBadPropertyError: (keyInput) ->
      keyInput.focus()
      tempError = @createTemporaryError('Invalid property name.')
      tempError.insertAfter(keyInput)
      return
  
    addNewChildForKey: (key) ->
      schema = @getChildSchema(key)
      newTreema = @addChildTreema(key, null, schema)
      newTreema.justAdded = true
      newTreema.tv4 = @tv4
      childNode = @createChildNode(newTreema)
      @findObjectInsertionPoint(key).before(childNode)
      if newTreema.collection then newTreema.addNewChild() else newTreema.edit()
      @updateMyAddButton()
  
    findObjectInsertionPoint: (key) ->
      # Object children should be in the order of the schema.properties objects as much as possible
      return @getAddButtonEl() unless @schema.properties?[key]
      allProps = Object.keys(@schema.properties)
      afterKeys = allProps.slice(allProps.indexOf(key)+1)
      allChildren = @$el.find('> .treema-children > .treema-node')
      for child in allChildren
        if $(child).data('instance').keyForParent in afterKeys
          return $(child)
      return @getAddButtonEl()
  
    childPropertiesAvailable: ->
      return [] unless @schema.properties
      properties = []
      for property, childSchema of @schema.properties
        continue if @data[property]?
        properties.push(childSchema.title or property)
      properties.sort()
  
    onDeletePressed: (e) ->
      super(e)
      return unless @addingNewProperty()
      keyInput = $(e.target)
      return unless keyInput.hasClass('treema-new-prop')
      if not keyInput.val()
        @clearTemporaryErrors()
        keyInput.remove()
        e.preventDefault()
  
    onEscapePressed: (e) ->
      keyInput = $(e.target)
      return unless keyInput.hasClass('treema-new-prop')
      @clearTemporaryErrors()
      keyInput.remove()
      e.preventDefault()
  
    onTabPressed: (e) ->
      e.preventDefault()
      keyInput = $(e.target)
      return super(e) unless keyInput.hasClass('treema-new-prop')
      return keyInput.blur() if keyInput.val() # pass to onNewPropertyBlur
      targetTreema = @getNextEditableTreemaFromElement(keyInput, if e.shiftKey then -1 else 1)
      keyInput.remove()
      targetTreema.edit() if targetTreema



  TreemaNode.setNodeSubclass 'any', class AnyNode extends TreemaNode
    """
    Super flexible input, can handle inputs like:
    true      -> true
    'true     -> 'true'
    'true'    -> 'true'
    1.2       -> 1.2
    [         -> []
    {         -> {}
    [1,2,3]   -> [1,2,3]
    null      -> null
    """
  
    helper: null
  
    constructor: (splat...) ->
      super(splat...)
      @updateShadowMethods()
  
    buildValueForEditing: (valEl) -> @buildValueForEditingSimply(valEl, JSON.stringify(@data))
    saveChanges: (valEl) ->
      @data =$('input', valEl).val()
      if @data[0] is "'" and @data[@data.length-1] isnt "'"
        @data = @data[1..]
      else if @data[0] is '"' and @data[@data.length-1] isnt '"'
        @data = @data[1..]
      else if @data.trim() is '['
        @data = []
      else if @data.trim() is '{'
        @data = {}
      else
        try
          @data = JSON.parse(@data)
        catch e
          console.log('could not parse data', @data)
      @updateShadowMethods()
      @rebuild()
  
    updateShadowMethods: ->
      # This node takes on the behaviors of the other basic nodes.
      NodeClass = TreemaNode.getNodeClassForSchema({type:$.type(@data)})
      @helper = new NodeClass(@schema, @data, @parent)
      @helper.tv4 = @tv4
      for prop in ['collection', 'ordered', 'keyed', 'getChildSchema', 'getChildren', 'getChildSchema',
                   'buildValueForDisplay']
        @[prop] = @helper[prop]
  
    rebuild: ->
      oldEl = @$el
      if @parent
        newNode = @parent.createChildNode(@)
      else
        newNode = @build()
  
      oldEl.replaceWith(newNode)
  
    onClick: (e) ->
      return if e.target.nodeName in ['INPUT', 'TEXTAREA']
      clickedValue = $(e.target).closest('.treema-value').length  # Clicks are in children of .treema-value nodes
      usedModKey = e.shiftKey or e.ctrlKey or e.metaKey
      return @toggleEdit() if clickedValue and not usedModKey
      super(e)