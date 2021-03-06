# How this plugin is structured:
# link.coffee (and eventually others like image, figure, exercise, etc) provides the following config:
# - selector: css selector for determining which elements to attach bubble events to
# - populator: Javscript function that gets (a) the element and (b) the div that represents the bubble.
#               This function will populate the bubble with buttons like "Add Title", "Change", etc
# - helper: This member will be set when you register your bubble with
#           register/bindHelper. Don't use it for something else.

# bubble.coffee contains the code to attach all the correct listeners (like mouse events)
#      moves the bubble to the correct spot, and triggers when the bubble should be populated


# This file manages all the Aloha events and removes/adds all the bubble listeners when an editable is enabled/disabled.

#############  The popover pseudo code: #############
# Here's the flow cases to consider:
# - User moves over a link and then moves it away (no popup)
# - User hovers over a link causing a bubble and then moves it away (delayed close to handle next case)
# - User hovers over a link causing a bubble and then moves it over the bubble (the bubble should not disappear)
# - User moves over a link and then clicks inside it (bubble shows up immediately and should not disappear)
# - User clicks on a link (or moves into it with the cursor) and then clicks/moves elsewhere (bubble should pop up immediately and close immediately)

###
----------------------
 State Machine
----------------------

(STATE_*) Denotes the initial State
(STATE_S) Denotes the "selected" State (when the cursor is in the element)
$el is the element (link, figure, title)
$tip is the popover element (tooltip)

There are 3 variables that are stored on each element;
[ isOpened, null/timer, isSelected ]


(STATE_*) [closed, _, _]
    |   |
    |   | (select via keyboard (left/right/up/down))
    |   |
    |   \----> (STATE_S) [opened, _, selected]
    |           |   |
    |           |   | (click elsewhere (not $el/$tip)
    |           |   |
    |           |   \----> (STATE_C) [closed, _, _]
    |           |
    |           | ($el/$tip.mouseenter)
    |           |
    |           \----> Nothing happens (unlike the other mouseenter case)
    |
    | ($el.mouseenter)
    |
    \----> (STATE_WC) [closed, timer, _] (waiting to show the popoup)
            |   |
            |   | ($el.mouseleave)
            |   |
            |   \----> (STATE_*)
            |
            | (... wait some time)
            |
            \----> (STATE_O) [opened, _, _] (hover popup displayed)
                    |   |
                    |   | (select via click or keyboard)
                    |   |
                    |   \---> (STATE_S) [opened, _, selected]
                    |
                    | ($el.mouseleave)
                    |
                    \----> (STATE_WO) [opened, timer, _] (mouse has moved away from $el but the popup hasn't disappeared yet) (POSFDGUOFDIGU)
                            |   |
                            |   | (... wait some time)
                            |   |
                            |   \---> (STATE_*) [closed, _, _]
                            |
                            | ($tip.mouseenter)
                            |
                            \---> (STATE_TIP) [opened, _, _]
                                    |
                                    | ($tip.mouseleave)
                                    |
                                    \---> (STATE_WO) [opened, timer, _]
                                            |   |
                                            |   | (... wait some time)
                                            |   |
                                            |   \----> (STATE_*) [closed, _, _]
                                            |
                                            \---> (STATE_TIP) [opened, _, _]

###

define [ 'aloha', 'jquery', 'css!overlay/css/popover.css' ], (Aloha, jQuery) ->

  popover_template = '''<div class="aloha popover"><div class="arrow"></div>
    <h3 class="popover-title"></h3>
    <div class="popover-content"></div></div>'''

  # This position code was refactored out because it is also used to move the
  # Popover when the document changes
  # Assumes @ is the Popover
  Bootstrap_Popover__position = ($tip, hint) ->
      placement = (if typeof @options.placement is "function" then @options.placement.call(@, $tip[0], @$element[0]) else @options.placement)
      inside = /in/.test(placement)
      # Start: Don't remove because then you lose all the events attached to the content of the tip
      #$tip.remove()
      # End: changes
      if not $tip.parents()[0]
        $tip.appendTo (if inside then @$element else document.body)
      pos = @getPosition(inside)
      actualWidth = $tip[0].offsetWidth
      actualHeight = $tip[0].offsetHeight
      actualPlacement = (if inside then placement.split(" ")[1] else placement)
      switch actualPlacement
        when "bottom"
          if hint
            tp =
              top: hint.top + 10
              left: hint.left - actualWidth / 2
          else
            tp =
              top: pos.top + pos.height
              left: pos.left + pos.width / 2 - actualWidth / 2
        when "top"
          if hint
            tp =
              top: hint.top - actualHeight - 10 # minus 10px for the arrow
              left: hint.left - actualWidth / 2
          else
            tp =
              top: pos.top - actualHeight - 10 # minus 10px for the arrow
              left: pos.left + pos.width / 2 - actualWidth / 2
        when "left"
          if hint
            tp =
              top: hint.top - actualHeight / 2
              left: hint.left - actualWidth
          else
            tp =
              top: pos.top + pos.height / 2 - actualHeight / 2
              left: pos.left - actualWidth
        when "right"
          if hint
            tp =
              top: hint.top - actualHeight / 2
              left: hint.left
          else
            tp =
              top: pos.top + pos.height / 2 - actualHeight / 2
              left: pos.left + pos.width

      # If no space at top, move to bottom. This attempts to keep the
      # popover inside the editable area by considering the top of
      # the editor and how far the document is scrolled.
      if actualPlacement == 'top' and tp.top < (
        Aloha.activeEditable and Aloha.activeEditable.obj.position().top or 0
        ) + jQuery(window).scrollTop()
        actualPlacement = 'bottom'
        tp.top = pos.top + pos.height

      if tp.left < 0
        # If no space to left, move to right.
        tp.left = 10 # so it's not right at the edge of the page
      else if tp.left + actualWidth > jQuery(window).width()
        # If it falls off on the right hand side, move it in.
        tp.left = jQuery(window).width() - actualWidth - 10

      # Remove any old positioning and reposition
      $tip.css(tp).removeClass("top bottom left right").addClass(
        actualPlacement)

  # Monkeypatch the bootstrap Popover so we can inject clickable buttons
  Bootstrap_Popover_show = () ->
    if @hasContent() and @enabled
      e = $.Event('show')
      @$element.trigger e
      if e.isDefaultPrevented()
        return

      $tip = @tip()
      @setContent()
      $tip.addClass "fade"  if @options.animation

      $tip.css(
        top: 0
        left: 0
        display: "block"
      )

      Bootstrap_Popover__position.bind(@)($tip)

      $tip.addClass "in"

      ### Trigger the shown event ###
      @$element.trigger('shown')

  Bootstrap_Popover_hide = (originalHide) -> () ->
      @$element.trigger('hide')
      originalHide.bind(@)()
      @$element.trigger('hidden')
      # return this
      @

  # Apply the monkey patch
  monkeyPatch = () ->
    console && console.warn('Monkey patching Bootstrap popovers so the buttons in them are clickable')
    proto = jQuery.fn.popover.Constructor.prototype
    proto.show = Bootstrap_Popover_show
    proto.hide = Bootstrap_Popover_hide(proto.hide)

  # We only want to apply the patches for old versions of bootstrap. With
  # no way to obtain the version of bootstrap, we need to look for some other
  # defining feature that is bound to be available. I use here the fact that
  # in 2.3 bootstrap added the 'container' option to tooltips/popovers, so
  # not having that is a sign that patching is needed.
  if typeof($.fn.tooltip.defaults.container) == 'undefined'
    monkeyPatch()

  Popover =
    MILLISECS: 2000
    register: (cfg) -> bindHelper(new Helper(cfg))

  class Helper
    constructor: (cfg) ->
      # @selector
      # @populator
      # @placement
      # @hover - Show the popover when the user hovers over an element
      @hover = false
      jQuery.extend(@, cfg)
      if @focus or @blur
        console and console.warn 'Popover.focus and Popover.blur are deprecated in favor of listening to the "shown" or "hidden" events on the original DOM element'

    startAll: (editable) ->
      $el = jQuery(editable.obj)

      delayTimeout = ($self, eventName, ms) ->
        return setTimeout(() ->
          $self.trigger eventName
        , ms)

      makePopovers = ($nodes) =>
        $nodes.each (i, node) =>
          $node = jQuery(node)

          # Make sure we don't create more than one popover for an element.
          if not $node.data('popover')
            if @focus
              $node.on 'shown.bubble', =>
                @focus.bind($node[0])($node.data('popover').$tip)
            if @blur
              $node.on 'hide.bubble', =>
                @blur.bind($node[0])($node.data('popover').$tip)

            # Specifying 'container: body' has no effect on bootstrap<2.3,
            # but on the newer versions it places the popover outside
            # the editor area, which avoids selecttion-changed events
            # firing while you type inside a popover.
            $node.popover
              html: true # bootstrap changed the default for this config option so set it to HTML
              placement: @placement or 'bottom'
              trigger: 'manual'
              template: popover_template
              container: 'body'
              content: =>
                @populator.bind($node)($node, @) # Can't quite decide whether the populator code should use @ or the 1st arg.

      $el.on 'show-popover.bubble', @selector, (evt, hint) =>
        $node = jQuery(evt.target)

        clearTimeout($node.data('aloha-bubble-timer'))
        $node.removeData('aloha-bubble-timer')
        if not $node.data('aloha-bubble-visible')
          # If the popover data hasn't been configured yet then configure it
          makePopovers($node)
          $node.popover 'show'
          if @markerclass
            $node.data('popover').$tip.addClass(@markerclass)
          $node.data('aloha-bubble-visible', true)
        # As long as the popover is open  move it around if the document changes ($el updates)
        that = $node.data('popover')
        if that and that.$tip
          Bootstrap_Popover__position.bind(that)(that.$tip, hint)
      $el.on 'hide-popover.bubble', @selector, (evt) =>
        $node = jQuery(evt.target)
        clearTimeout($node.data('aloha-bubble-timer'))
        $node.removeData('aloha-bubble-timer')
        $node.data('aloha-bubble-selected', false)
        if $node.data('aloha-bubble-visible')
          $node.popover 'hide'
          $node.removeData('aloha-bubble-visible')

      # The only reason I map mouseenter is so I can catch new elements that are added to the DOM
      $el.on 'mouseenter.bubble', @selector, (evt) =>
        $node = jQuery(evt.target)
        clearInterval($node.data('aloha-bubble-timer'))

        if @hover
          ## (STATE_*) -> (STATE_WC)
          $node.data('aloha-bubble-timer', delayTimeout($node, 'show', Popover.MILLISECS)) ## (STATE_WC) -> (STATE_O)
          $node.on 'mouseleave.bubble', =>
            if not $node.data('aloha-bubble-selected')
              # You have 500ms to move from the tag in the DOM to the popover.
              # If the mouse enters the popover then cancel the 'hide'
              try
                $tip = $node.data('popover').$tip
              catch err
                $tip = null
              if $tip
                $tip.on 'mouseenter', =>
                  ## (STATE_WO) -> (STATE_TIP)
                  clearTimeout($node.data('aloha-bubble-timer'))
                $tip.on 'mouseleave', =>
                  clearTimeout($node.data('aloha-bubble-timer'))
                  if not $node.data('aloha-bubble-selected')
                    $node.data('aloha-bubble-timer', delayTimeout($node, 'hide', Popover.MILLISECS / 2)) ## (STATE_WO) -> (STATE_*)

              $node.data('aloha-bubble-timer', delayTimeout($node, 'hide', Popover.MILLISECS / 2)) if not $node.data('aloha-bubble-timer')

    stopAll: (editable) =>
      # Remove all event handlers and close all bubbles
      $nodes = jQuery(editable.obj).find(@selector)
      this.stopOne($nodes)
      jQuery(editable.obj).off('.bubble', @selector)

    stopOne: ($nodes) ->
      $nodes.trigger 'hide-popover'
      $nodes.removeData('aloha-bubble-selected')
      $nodes.popover('destroy')

  findMarkup = (range=Aloha.Selection.getRangeObject(), selector) ->
    if Aloha.activeEditable
      filter = () ->
        $el = jQuery(@)
        $el.is(selector) or $el.parents(selector)[0]
      range.findMarkup filter, Aloha.activeEditable.obj
    else
      null

  # Validate and save the href if something is selected.
  selectionChangeHandler = (rangeObject, selector) ->
    enteredLinkScope = false

    # Check if we need to ignore this selection changed event for
    # now and check whether the selection was placed within a
    # editable area.
    if Aloha.activeEditable? #HACK things like math aren't SelectionEditable but we still want a popup: Aloha.Selection.isSelectionEditable() and Aloha.activeEditable?
      foundMarkup = findMarkup(rangeObject, selector)
      enteredLinkScope = foundMarkup
    enteredLinkScope

  bindHelper = (cfg) ->
    helper = new Helper(cfg)
    # Place the created helper back onto the registering module, so we might
    # locate it later
    $.extend(cfg, helper: helper)

    # These are reset when the editor is deactivated
    insideScope = false
    enteredLinkScope = false

    Aloha.bind 'aloha-editable-activated', (event, data) ->
      helper.startAll(data.editable)
    Aloha.bind 'aloha-editable-deactivated', (event, data) ->
      helper.stopAll(data.editable)
      insideScope = false

    Aloha.bind 'aloha-editable-created', (evt, editable) ->
      # When a popover is hidden, the next selection change should
      # do the right thing.
      editable.obj.on 'hidden', helper.selector, () ->
        insideScope = false

    Aloha.bind 'aloha-selection-changed', (event, rangeObject, originalEvent) ->
      # How this is even possible I do not understand, but apparently it is
      # possible for our helper to not be completely initialised at this point.
      if not (helper.populator and helper.selector)
        return

      # Hide all popovers except for the current one maybe?
      $el = jQuery(rangeObject.getCommonAncestorContainer())
      $el = $el.parents(helper.selector).eq(0) if not $el.is(helper.selector)

      if Aloha.activeEditable
        # Hide other tooltips of the same type
        nodes = jQuery(Aloha.activeEditable.obj).find(helper.selector)
        nodes = nodes.not($el)
        nodes.trigger 'hide-popover'

        enteredLinkScope = selectionChangeHandler(rangeObject, helper.selector)
        if insideScope isnt enteredLinkScope
          insideScope = enteredLinkScope
          if not $el.is(helper.selector)
            $el = $el.parents(helper.selector).eq(0)
          if enteredLinkScope
            if originalEvent and originalEvent.pageX
              $el.trigger 'show-popover',
                top: originalEvent.pageY, left: originalEvent.pageX
            else
              $el.trigger 'show-popover'
            $el.data('aloha-bubble-selected', true)
            $el.off('.bubble')
            event.stopPropagation()

    return helper

  return Popover
