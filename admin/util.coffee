Handlebars.registerHelper "_tsLookupTreatment", -> Treatments.findOne("" + (@_id || @))
Handlebars.registerHelper "_tsLookupUser", -> Meteor.users.findOne("" + (@_id || @))

Handlebars.registerHelper "_tsLookupWorker", -> Meteor.users.findOne(workerId: "" + (@workerId || @))

Handlebars.registerHelper "_tsRenderTime", (timestamp) -> new Date(timestamp).toLocaleString()

Handlebars.registerHelper "_tsRenderISOTime", (isoString) ->
  m = moment(isoString)
  return m.format("l LT") + " (" + m.fromNow() + ")"

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
    placement: "auto"
    trigger: "hover"
    container: @firstNode
    content: =>
      UI.toHTML(Template.tsUserPillPopover.extend(data: => @data))

Template.tsDescList.properties = ->
  result = []
  for key, value of this
    result.push key: key, value: value
  return result
