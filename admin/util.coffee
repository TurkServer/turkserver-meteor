@Util = {}

Util.duration = (millis) ->
  diff = moment.utc(millis)
  time = diff.format("H:mm:ss")
  days = +diff.format("DDD") - 1
  return (if days isnt 0 then days + "d " else "") + time

Util.timeSince = (timestamp) -> Util.duration(TimeSync.serverTime() - timestamp)
Util.timeUntil = (timestamp) -> Util.duration(timestamp - TimeSync.serverTime())

UI.registerHelper "_tsViewingBatch", -> Batches.findOne(Session.get("_tsViewingBatchId"))

UI.registerHelper "_tsLookupTreatment", -> Treatments.findOne(name: ""+@)

UI.registerHelper "_tsRenderTime", (timestamp) -> new Date(timestamp).toLocaleString()

UI.registerHelper "_tsRenderTimeSince", Util.timeSince
UI.registerHelper "_tsRenderTimeUntil", Util.timeUntil

UI.registerHelper "_tsRenderISOTime", (isoString) ->
  m = moment(isoString)
  return m.format("l T") + " (" + m.fromNow() + ")"

Template.tsBatchSelector.events =
  "change select": (e) ->
    unless Session.equals("_tsViewingBatchId", e.target.value)
      Session.set("_tsViewingBatchId", e.target.value)

Template.tsBatchSelector.batches = -> Batches.find()
Template.tsBatchSelector.noBatchSelection = -> not Session.get("_tsViewingBatchId")
Template.tsBatchSelector.selected = -> Session.equals("_tsViewingBatchId", @_id)

Template.tsInstancePill.instance = -> Experiments.findOne(""+@)

Template.tsInstancePill.rendered = ->
  container = @$(".ts-instance-pill-container")
  container.popover
    html: true
    placement: "auto right"
    trigger: "hover"
    container: container
    content: =>
      # FIXME: Workaround as popover doesn't update with changed data
      # https://github.com/meteor/meteor/issues/2010#issuecomment-40532280
      UI.toHTML Template.tsAdminGroupInfo.extend data: UI.getElementData(container[0])

Template.tsUserPill.user = ->
  switch
    when @userId then Meteor.users.findOne(@userId)
    when @workerId then Meteor.users.findOne(workerId: @workerId)
    else @ # Object was already passed in

Template.tsUserPill.labelClass = ->
  switch
    when @status?.idle then "label-warning"
    when @status?.online then "label-success"
    else "label-default"

Template.tsUserPill.identifier = ->
  if @username
    @username
  else if @workerId
    "(" + @workerId + ")"
  else
    "(" + @_id + ")"

Template.tsUserPill.rendered = ->
  container = @$(".ts-user-pill-container")
  container.popover
    html: true
    placement: "auto right"
    trigger: "hover"
    container: container
    content: =>
      # FIXME: Workaround as popover doesn't update with changed data
      # https://github.com/meteor/meteor/issues/2010#issuecomment-40532280
      UI.toHTML Template.tsUserPillPopover.extend data: UI.getElementData(container[0])

Template.tsDescList.properties = ->
  result = []
  for key, value of this
    result.push key: key, value: value
  return result

# Special rules for rendering description lists
Template.tsDescList.value = ->
  switch
    when @value is false then "false"
    when _.isObject(@value) then JSON.stringify(@value)
    else @value
