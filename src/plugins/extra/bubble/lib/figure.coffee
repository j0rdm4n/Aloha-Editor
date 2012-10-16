# Aloha Link Plugin
# * -----------------
# * This plugin provides a bubble next to a link when it is selected
# 
define ['aloha', 'jquery', 'aloha/console'], (Aloha, jQuery, console) ->
  
  selector = 'figure'
  filter = ->
    @nodeName.toLowerCase() is 'figure' or jQuery(@).parents('figure')[0]

  # TODO: Convert the mousedown to a click. To do that the aloha-deactivated event need to not hide the bubbles yet and instead fire a 'hide' event
  populator = ($bubble) ->
      $el = @
      $bubble = jQuery('<div class="figure-popover btn-group"></div>')
      # Buttons to add/remove a title/caption
      if $el.children('.title')[0]
        $button = jQuery('<button class="btn btn-danger">Remove Title</button>')
        $button.on 'mousedown', () -> $el.children('.title').remove()
        $bubble.append($button)
      else
        $button = jQuery('<button class="btn">Add Title</button>')
        $button.on 'mousedown', () ->
          newTitle = jQuery('<div class="title aloha-optional aloha-empty">Insert Title Here</div>')
          $el.prepend(newTitle)
          #TODO: Select the title
        $bubble.append($button)
      
      separator = jQuery('<span class="divider"></span>')
      $bubble.append(separator)
      
      if $el.children('figcaption')[0]
        $button = jQuery('<button class="btn btn-danger">Remove Caption</button>')
        $button.on 'mousedown', () -> $el.children('figcaption').remove()
        $bubble.append($button)
      else
        $button = jQuery('<button class="btn">Add Caption</button>')
        $button.on 'mousedown', () ->
          newCaption = jQuery('<figcaption class="aloha-optional aloha-empty">Insert Caption Here</figcaption>')
          $el.append(newCaption)
        $bubble.append($button)
      
      $bubble #.contents()



  return {
    selector: selector
    populator: populator
    filter: filter
  }