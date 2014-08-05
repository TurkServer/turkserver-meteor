quals = -> Qualifications.find()
hitTypes = -> HITTypes.find()

Template.tsAdminMTurk.selectedHITType = -> HITTypes.findOne Session.get("_tsSelectedHITType")

Template.tsAdminHitTypes.events =
  "click tr": -> Session.set("_tsSelectedHITType", @_id)
  "click .-ts-new-hittype": -> Session.set("_tsSelectedHITType", undefined)

Template.tsAdminHitTypes.hitTypes = hitTypes
Template.tsAdminHitTypes.selectedClass = ->
  if Session.equals("_tsSelectedHITType", @_id) then "info" else ""

Template.tsAdminViewHitType.events =
  "click .-ts-register-hittype": ->
    Meteor.call "ts-admin-register-hittype", @_id, (err, res) ->
      bootbox.alert(err.reason) if err
  "click .-ts-delete-hittype": ->
    HITTypes.remove(@_id)

Template.tsAdminViewHitType.batchName = -> Batches.findOne(@batchId)?.name || "(none)"
Template.tsAdminViewHitType.renderReward = -> @Reward.toFixed(2)
Template.tsAdminViewHitType.qualName = -> Qualifications.findOne(""+@)?.name

Template.tsAdminNewHitType.events =
  "submit form": (e, tmpl) ->
    e.preventDefault()

    id = HITTypes.insert
      batchId: tmpl.find("select[name=batch]").value
      Title: tmpl.find("input[name=title]").value
      Description: tmpl.find("textarea[name=desc]").value
      Keywords: tmpl.find("input[name=keywords]").value
      Reward: tmpl.find("input[name=reward]").valueAsNumber
      QualificationRequirement: $(tmpl.find("select[name=quals]")).val()
      AssignmentDurationInSeconds: tmpl.find("input[name=duration]").valueAsNumber
      AutoApprovalDelayInSeconds: tmpl.find("input[name=delay]").valueAsNumber

    Session.set("_tsSelectedHITType", id)

Template.tsAdminNewHitType.quals = quals

Template.tsAdminNewHitType.batches = Batches.find()

Template.tsAdminQuals.events =
  "click .-ts-delete-qual": ->
    Qualifications.remove(@_id)

Template.tsAdminQuals.quals = quals

Template.tsAdminQuals.value = ->
  if @IntegerValue
    return @IntegerValue + " (Integer)"
  else if @LocaleValue
    return @LocaleValue + " (Locale)"
  else
    return

Template.tsAdminNewQual.events =
  "click .-ts-create-qual": (e, tmpl) ->
    name = tmpl.find("input[name=name]").value
    type = tmpl.find("input[name=type]").value
    comp = tmpl.find("select[name=comp]").value
    value = tmpl.find("input[name=value]").value

    return if !name or !type or !comp

    qual =
      name: name
      QualificationTypeId: type
      Comparator: comp

    try
      switch comp
        when "Exists", "DoesNotExist"
          throw new Error("No value should be specified for Exists or DoesNotExist") if !!value

        when "In", "NotIn"
          # Parse value as a comma-separated array
          vals = []
          type = null

          # Check that they are all the same type
          # TODO we don't check for the validity of the type here
          for v in value.split(/[\s,]+/)
            continue if !v

            if numV = parseInt(v)
              vals.push(numV)
              newType = "Integer"
            else
              vals.push(v)
              newType = "String"

            throw new Error("Must be all Integers or Locales") if type? and newType isnt type
            type = newType

          throw new Error("Must specify at least one value for In or NotIn") unless type?

          if type is "Integer"
            qual.IntegerValue = vals
          else
            qual.LocaleValue = vals

        else # Things with values
          if !!value
            if parseInt(value)
              qual.IntegerValue = value
            else
              qual.LocaleValue = value

      Qualifications.insert(qual)
    catch e
      bootbox.alert(e.toString())

Template.tsAdminHits.events =
  "click tr": -> Session.set("_tsSelectedHIT", @_id)

Template.tsAdminHits.hits = -> HITs.find()
Template.tsAdminHits.selectedHIT = -> HITs.findOne Session.get("_tsSelectedHIT")

Template.tsAdminViewHit.events =
  "click .-ts-refresh-hit": ->
    Meteor.call "ts-admin-refresh-hit", @HITId, (err, res) ->
      bootbox.alert(err.reason) if err

  "click .-ts-expire-hit": ->
    Meteor.call "ts-admin-expire-hit", @HITId, (err, res) ->
      bootbox.alert(err.reason) if err

  "submit .-ts-change-hittype": (e, tmpl) ->
    e.preventDefault()
    htId = tmpl.find("select[name=hittype]").value
    HITTypeId = HITTypes.findOne(htId).HITTypeId
    unless HITTypeId
      bootbox.alert("Register that HIT Type first")
      return

    params =
      HITId: @HITId
      HITTypeId: HITTypeId
    Meteor.call "ts-admin-change-hittype", params, (err, res) ->
      bootbox.alert(err.reason) if err

  "submit .-ts-extend-assignments": (e, tmpl) ->
    e.preventDefault()
    params =
      HITId: @HITId
      MaxAssignmentsIncrement: tmpl.find("input[name=assts]").valueAsNumber
    Meteor.call "ts-admin-extend-hit", params, (err, res) ->
      bootbox.alert(err.reason) if err

  "submit .-ts-extend-expiration": (e, tmpl) ->
    e.preventDefault()
    params =
      HITId: @HITId
      ExpirationIncrementInSeconds: tmpl.find("input[name=secs]").valueAsNumber
    Meteor.call "ts-admin-extend-hit", params, (err, res) ->
      bootbox.alert(err.reason) if err

Template.tsAdminViewHit.hitTypes = hitTypes

Template.tsAdminNewHit.events =
  "submit form": (e, tmpl) ->
    e.preventDefault()

    hitTypeId = tmpl.find("select[name=hittype]").value

    unless hitTypeId
      bootbox.alert("HIT Type isn't registered")
      return

    params =
      MaxAssignments: tmpl.find("input[name=maxAssts]").valueAsNumber
      LifetimeInSeconds: tmpl.find("input[name=lifetime]").valueAsNumber

    Meteor.call "ts-admin-create-hit", hitTypeId, params, (err, res) ->
      bootbox.alert(err.reason) if err

Template.tsAdminNewHit.hitTypes = hitTypes

Template.tsAdminWorkers.settings = {
  position: "bottom",
  limit: 5,
  rules: [
    {
      collection: Meteor.users,
      field: "workerId",
      template: Template.tsAdminWorkerItem
      callback: (user) ->
        Router.go("workers", {workerId: user.workerId}) if user.workerId?
    }
  ]
}

Template.tsAdminWorkers.workerData = -> Workers.findOne(@workerId)

Template.tsAdminWorkers.workerActiveAssts = ->
  Assignments.find({
    workerId: @workerId,
    status: { $ne: "completed" }
  }, {
    sort: acceptTime: -1
  })

Template.tsAdminWorkers.workerCompletedAssts = ->
  Assignments.find({
    workerId: @workerId,
    status: "completed"
  }, {
    sort: submitTime: -1
  })

Template.tsAdminPanel.rendered = ->
  svg = d3.select(@find("svg"))
  $svg = @$("svg")

  margin =
    left: 90
    bottom: 30

  x = d3.scale.linear()
    .range([0, $svg.width() - margin.left])

  y = d3.scale.ordinal()
    # Data was originally stored in GMT -5 so just display that
    .domain(m.zone(300).format("HH ZZ") for m in TurkServer.Util._defaultTimeSlots())
    .rangeBands([0, $svg.height() - margin.bottom], 0.2)

  xAxis = d3.svg.axis()
    .scale(x)
    .orient("bottom")

  yAxis = d3.svg.axis()
    .scale(y)
    .orient("left")

  # Draw axes
  chart = svg.append("g")
    .attr("transform", "translate(" + margin.left + ",0)")

  chart.append("g")
    .attr("class", "x axis")
    .attr("transform", "translate(0," + ($svg.height() - margin.bottom) + ")")
    .call(xAxis)

  chart.append("g")
    .attr("class", "y axis")
    .call(yAxis)
  .append("text")
    .attr("transform", "rotate(-90)")
    .attr("y", -80)
    .attr("dy", ".71em")
    .style("text-anchor", "end")
    .text("Timezone")

  data = {}

  newData = false
  redraw = ->
    return unless newData
    newData = false

    entries = d3.entries(data)

    # Update domain with max value
    x.domain([0, d3.max(entries, (d) -> d.value)])
    chart.select("g.x.axis").call(xAxis)

    bars = chart.selectAll(".bar")
      .data(entries, (d) -> d.key)

    # Add any new bars in the enter selection
    bars.enter()
      .append("rect")
      .attr("class", "bar")
      .attr("y", (d) -> y(d.key) )
      .attr("height", y.rangeBand());

    # Update widths in the update selection, including entered nodes
    bars.attr("data-value", (d) -> d.value )
      .transition()
      .attr("width", (d) -> x(d.value) )

  # Aggregate the worker times into the current timezone
  @handle = Workers.find().observeChanges
    added: (id, fields) ->
      # Only use data from workers who agreed to be contacted
      return unless fields.contact and fields.available?
      for time in fields.available.times
        # normalize into buckets
        continue unless time # Ignore invalid (empty) entries
        data[time] ?= 0
        data[time] += 1

      newData = true
      Meteor.defer(redraw)

Template.tsAdminPanel.destroyed = ->
  @handle.stop()

Template.tsAdminPanel.workerContact = -> Workers.find(contact: true).count()
Template.tsAdminPanel.workerTotal = -> Workers.find().count()

Template.tsAdminEmail.messages = -> WorkerEmails.find({}, {sort: {sentTime: -1}})

Template.tsAdminEmail.events
  "click tr": -> Session.set("_tsSelectedEmailId", @_id)

Template.tsAdminEmailMessage.selectedMessage = ->
  emailId = Session.get("_tsSelectedEmailId")
  return WorkerEmails.findOne(emailId) if emailId?

Template.tsAdminEmailMessage.events
  "click .ts-admin-send-message": ->
    Meteor.call "ts-admin-send-message", @_id, (err, res) ->
      if err?
        bootbox.alert(err)
      else
        bootbox.alert("#{res} workers notified!")

  "click .ts-admin-resend-message": ->
    Meteor.call "ts-admin-resend-message", @_id, (err) ->
      bootbox.alert(err) if err?

  "click .ts-admin-delete-message": ->
    Meteor.call "ts-admin-delete-message", @_id, (err) ->
      bootbox.alert(err) if err?

Template.tsAdminNewEmail.messages = ->
  WorkerEmails.find({}, {
    fields: {subject: 1},
    sort: {sentTime: -1}
  })

Template.tsAdminNewEmail.events
  "submit form": (e, t) ->
    e.preventDefault()
    $sub = t.$("input[name=subject]")
    $msg = t.$("textarea[name=message]")

    subject = $sub.val()
    message = $msg.val()

    if t.$("input[name=recipients]:checked").val() is "copy"
      copyFromId = t.$("select[name=copyFrom]").val()
      unless copyFromId?
        bootbox.alert("Select an e-mail to copy recipients from")
        return

    Meteor.call "ts-admin-create-message", subject, message, copyFromId, (err, res) ->
      if err?
        bootbox.alert(err)
      else
        # Display the new message
        Session.set("_tsSelectedEmailId", res)

Template.tsAdminAssignmentMaintenance.events
  "click .-ts-cancel-assignments": ->
    message = "This will cancel all assignments of users are disconnected. You should only do this if these users will definitely not return to their work. Continue? "
    bootbox.confirm message, (res) ->
      return unless res
      Meteor.call "ts-admin-cancel-assignments", Session.get("_tsViewingBatchId"), (err, res) ->
        bootbox.alert(err) if err?
        bootbox.alert(res + " assignments canceled") if res?

numAssignments = -> Assignments.find().count()

Template.tsAdminActiveAssignments.numAssignments = numAssignments

Template.tsAdminActiveAssignments.activeAssts = ->
  Assignments.find {}, { sort: acceptTime: -1 }

Template.tsAdminCompletedAssignments.events
  "submit form.ts-admin-assignment-filter": (e, t) ->
    e.preventDefault()

    Router.go "completedAssignments",
      days: t.find("input[name=filter_days]").valueAsNumber ||
        TurkServer.adminSettings.defaultDaysThreshold
      limit: t.find("input[name=filter_limit]").valueAsNumber ||
        TurkServer.adminSettings.defaultLimit

  "click .-ts-refresh-assignment": ->
    Meteor.call "ts-admin-refresh-assignment", this._id, (err) ->
      bootbox.alert(err) if err?

Template.tsAdminCompletedAssignments.numAssignments = numAssignments

Template.tsAdminCompletedAssignments.completedAssts = ->
  Assignments.find {}, { sort: submitTime: -1 }

Template.tsAdminCompletedAssignmentRow.labelStatus = ->
  switch @mturkStatus
    when "Submitted" then "label-warning"
    when "Approved" then "label-primary"
    when "Rejected" then "label-danger"
    else "label-default"
