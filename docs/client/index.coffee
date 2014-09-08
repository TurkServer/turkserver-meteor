# Because of
# Attributes on <body> not supported
Template.body.rendered = ->
  $('body').scrollspy(target: "#menu")
  hljs.initHighlightingOnLoad()

# Get templates automagically
# All things that don't start with an underscore
UI.registerHelper "sections", _.filter _.keys(Template), (name) ->
  char = name[0]
  # Doesn't start with underscore, and isn't a lowercase letter
  return char isnt "_" and char isnt char.toLowerCase()

Template._menu.events =
  # Smooth scrolling
  "click .nav a": (e) ->
    e.preventDefault()
    $.scrollTo(e.target.hash, "slow")

# Lowercase and remove spaces
Template._menu.id = -> @toLowerCase().replace(/\ /g, "")

Template._section.theTemplate = -> Template[@]
