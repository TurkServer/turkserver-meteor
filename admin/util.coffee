Handlebars.registerHelper "_tsLookupTreatment", -> Treatments.findOne("" + (@_id || @))
Handlebars.registerHelper "_tsLookupUser", -> Meteor.users.findOne("" + (@_id || @))

Handlebars.registerHelper "_tsRenderTime", (timestamp) -> new Date(timestamp).toLocaleString()

Template.tsUserPill.labelClass = -> if @status?.online then "label-success" else "label-default"

Template.tsUserPill.identifier = ->
  if @username
    @username
  else if @workerId
    "(" + @workerId + ")"
  else
    "(" + @_id + ")"

Template.tsUserPill.rendered = ->
  $(@firstNode).popover
    html: true
    placement: "left"
    trigger: "hover"
    container: @firstNode
    content: => Template.tsUserPillPopover(@data)
