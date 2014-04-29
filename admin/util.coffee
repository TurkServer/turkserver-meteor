@Util = {}

Util.duration = (millis) ->
  diff = moment.utc(millis)
  time = diff.format("H:mm:ss")
  days = +diff.format("DDD") - 1
  return (if days isnt 0 then days + "d " else "") + time

Util.timeSince = (timestamp) -> Util.duration(TimeSync.serverTime() - timestamp)
Util.timeUntil = (timestamp) -> Util.duration(timestamp - TimeSync.serverTime())

UI.registerHelper "_tsLookupTreatment", ->
  treatmentId = "" + (@_id || @)
  return Treatments.findOne(treatmentId) || treatmentId

UI.registerHelper "_tsLookupUser", -> Meteor.users.findOne("" + (@_id || @))

UI.registerHelper "_tsLookupWorker", -> Meteor.users.findOne(workerId: "" + (@workerId || @))

UI.registerHelper "_tsRenderTime", (timestamp) -> new Date(timestamp).toLocaleString()

UI.registerHelper "_tsRenderTimeSince", Util.timeSince
UI.registerHelper "_tsRenderTimeUntil", Util.timeUntil

UI.registerHelper "_tsRenderISOTime", (isoString) ->
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
    placement: "auto right"
    trigger: "hover"
    container: @firstNode
    content: =>
      # FIXME: Workaround as popover doesn't update with changed data
      # https://github.com/meteor/meteor/issues/2010#issuecomment-40532280
      UI.toHTML Template.tsUserPillPopover.extend data: UI.getElementData(@firstNode)

Template.tsDescList.properties = ->
  result = []
  for key, value of this
    result.push key: key, value: value
  return result

# Special rules for rendering description lists
Template.tsDescList.value = ->
  switch @value
    when false then "false"
    else @value
