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

TurkServer.callWithModal = (args..., callback) ->
  dialog = bootbox.dialog
    closeButton: false
    message: "<h3>Working...</h3>"

  # If callback is not specified, assume it is just an argument.
  unless _.isFunction(callback)
    args.push(callback)
    callback = null

  # Add our own callback that alerts for errors
  args.push (err, res) ->
    dialog.modal("hide")
    if err?
      bootbox.alert(err)
      return

    # If callback is given, calls it with data, otherwise just alert
    if res? && callback?
      callback(res)
    else if res?
      bootbox.alert(res)

  return Meteor.call.apply(null, args)

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

Template.tsBatchSelector.helpers
  batches: -> Batches.find({}, {sort: {name: 1}})
  noBatchSelection: -> not Session.get("_tsViewingBatchId")
  selected: -> Session.equals("_tsViewingBatchId", @_id)
  viewingBatchId: -> Session.get("_tsViewingBatchId")

Template.tsAdminInstance.rendered = ->
  # Subscribe to instance with whatever we rendered with
  this.autorun ->
    Meteor.subscribe "tsAdminInstance", Blaze.getData()

Template.tsAdminInstance.helpers
  instance: -> Experiments.findOne(@+"")

Template.tsAdminPayBonus.events
  "submit form": (e, t) ->
    e.preventDefault()
    amount = t.find("input[name=amount]").valueAsNumber
    reason = t.find("textarea[name=reason]").value

    $(t.firstNode).closest(".bootbox.modal").modal('hide')

    TurkServer.callWithModal("ts-admin-pay-bonus", @_id, amount, reason)

Template.tsAdminEmailWorker.events
  "submit form": (e, t) ->
    e.preventDefault()
    subject = t.find("input[name=subject]").value
    message = t.find("textarea[name=message]").value
    recipients = [@workerId]

    emailId = WorkerEmails.insert({ subject, message, recipients })

    $(t.firstNode).closest(".bootbox.modal").modal('hide')

    TurkServer.callWithModal("ts-admin-send-message", emailId)

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

Template.tsAdminWorkerItem.helpers
  labelClass: userLabelClass
  identifier: userIdentifier

Template.tsUserPill.helpers
  user: ->
    switch
      when @userId then Meteor.users.findOne(@userId)
      when @workerId then Meteor.users.findOne(workerId: @workerId)
      else @ # Object was already passed in
  labelClass: userLabelClass
  identifier: userIdentifier

Template.tsUserPill.events
  "click .ts-admin-email-worker": ->
    TurkServer._displayModal Template.tsAdminEmailWorker, this

Template.tsDescList.helpers
  properties: ->
    result = []
    for key, value of this
      result.push key: key, value: value
    return result
  # Special rules for rendering description lists
  value: ->
    switch
      when @value is false then "false"
      when _.isObject(@value) then JSON.stringify(@value)
      else nl2br(@value)
