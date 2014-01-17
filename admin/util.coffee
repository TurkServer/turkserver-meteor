Handlebars.registerHelper "_tsLookupTreatment", -> Treatments.findOne("" + (@_id || @))
Handlebars.registerHelper "_tsLookupUser", -> Meteor.users.findOne("" + (@_id || @))

Handlebars.registerHelper "_tsRenderTime", (timestamp) -> new Date(timestamp).toLocaleString()

Template.tsUserPill.labelClass = -> if @status?.online then "label-success" else "label-default"
Template.tsUserPill.identifier = ->
  if @username and @workerId
    @username + "(" + @workerId + ")"
  else if @workerId
    @workerId
  else
    "(" + @_id + ")"

Template.tsUserPill.rendered = ->
  $(@firstNode).popover
    html: true
    placement: "top"
    trigger: "hover"
    # Only need the below if we want to hover into; messes up text.
    # container: @firstNode
    content: => Template.tsUserPillPopover(@data)
