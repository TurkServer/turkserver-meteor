TurkServer.Util ?= {}

TurkServer.Util.duration = (millis) ->
  diff = moment.utc(millis)
  time = diff.format("H:mm:ss")
  days = +diff.format("DDD") - 1
  return (if days isnt 0 then days + "d " else "") + time

TurkServer.Util.timeSince = (timestamp) ->
  TurkServer.Util.duration(TimeSync.serverTime() - timestamp)
TurkServer.Util.timeUntil = (timestamp) ->
  TurkServer.Util.duration(timestamp - TimeSync.serverTime())

UI.registerHelper "_tsViewingBatch", -> Batches.findOne(Session.get("_tsViewingBatchId"))

UI.registerHelper "_tsLookupTreatment", -> Treatments.findOne(name: ""+@)

UI.registerHelper "_tsRenderTime", (timestamp) -> new Date(timestamp).toLocaleString()
UI.registerHelper "_tsRenderTimeMillis", (timestamp) ->
  m = moment(timestamp)
  m.format("L h:mm:ss.SSS A")

UI.registerHelper "_tsRenderTimeSince", TurkServer.Util.timeSince
UI.registerHelper "_tsRenderTimeUntil", TurkServer.Util.timeUntil

UI.registerHelper "_tsRenderISOTime", (isoString) ->
  m = moment(isoString)
  return m.format("L LT") + " (" + m.fromNow() + ")"

# https://github.com/kvz/phpjs/blob/master/functions/strings/nl2br.js
nl2br = (str) -> (str + '').replace(/([^>\r\n]?)(\r\n|\n\r|\r|\n)/g, '$1<br>$2')

UI.registerHelper "_tsnl2br", nl2br

Template.tsBatchSelector.events =
  "change select": (e) ->
    unless Session.equals("_tsViewingBatchId", e.target.value)
      Session.set("_tsViewingBatchId", e.target.value)

Template.tsBatchSelector.batches = -> Batches.find()
Template.tsBatchSelector.noBatchSelection = -> not Session.get("_tsViewingBatchId")
Template.tsBatchSelector.selected = -> Session.equals("_tsViewingBatchId", @_id)
Template.tsBatchSelector.viewingBatchId = -> Session.get("_tsViewingBatchId")

Template.tsAdminInstance.rendered = ->
  # Subscribe to instance with whatever we rendered with
  this.autorun ->
    Meteor.subscribe "tsAdminInstance", Blaze.getCurrentData()

Template.tsAdminInstance.instance = -> Experiments.findOne(@+"")

Template.tsAdminPayBonus.events
  "submit form": (e, t) ->
    e.preventDefault()
    amount = t.find("input[name=amount]").valueAsNumber
    reason = t.find("textarea[name=reason]").value

    Meteor.call "ts-admin-pay-bonus", @_id, amount, reason, (err) ->
      bootbox.alert(err) if err
    # Close the modal
    $(t.firstNode).closest(".bootbox.modal").modal('hide')

userLabelClass = ->
  switch
    when @status?.idle then "label-warning"
    when @status?.online then "label-success"
    else "label-default"

userIdentifier = ->
  if @username
    @username
  else if @workerId
    "(" + @workerId + ")"
  else
    "(" + @_id + ")"

Template.tsAdminWorkerItem.labelClass = userLabelClass
Template.tsAdminWorkerItem.identifier = userIdentifier

Template.tsUserPill.user = ->
  switch
    when @userId then Meteor.users.findOne(@userId)
    when @workerId then Meteor.users.findOne(workerId: @workerId)
    else @ # Object was already passed in

Template.tsUserPill.labelClass = userLabelClass
Template.tsUserPill.identifier = userIdentifier

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
    else nl2br(@value)
