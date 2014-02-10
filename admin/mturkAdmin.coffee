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

Template.tsAdminViewHitType.renderReward = -> @Reward.toFixed(2)
Template.tsAdminViewHitType.qualName = -> Qualifications.findOne(""+@)?.name

Template.tsAdminNewHitType.events =
  "submit form": (e, tmpl) ->
    e.preventDefault()

    id = HITTypes.insert
      Title: tmpl.find("input[name=title]").value
      Description: tmpl.find("textarea[name=desc]").value
      Keywords: tmpl.find("input[name=keywords]").value
      Reward: tmpl.find("input[name=reward]").valueAsNumber
      QualificationRequirement: $(tmpl.find("select[name=quals]")).val()
      AssignmentDurationInSeconds: tmpl.find("input[name=duration]").valueAsNumber
      AutoApprovalDelayInSeconds: tmpl.find("input[name=delay]").valueAsNumber

    Session.set("_tsSelectedHITType", id)

Template.tsAdminNewHitType.quals = quals

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

    if !!value
      if parseInt(value)
        qual.IntegerValue = value
      else
        qual.LocaleValue = value

    Qualifications.insert(qual)

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
    params =
      HITId: @HITId
      HITTypeId: tmpl.find("select[name=hittype]").value
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

    params =
      MaxAssignments: tmpl.find("input[name=maxAssts]").valueAsNumber
      LifetimeInSeconds: tmpl.find("input[name=lifetime]").valueAsNumber

    Meteor.call "ts-admin-create-hit", hitTypeId, params, (err, res) ->
      bootbox.alert(err.reason) if err

Template.tsAdminNewHit.hitTypes = hitTypes

Template.tsAdminPanel.rendered = ->
  # for now, statically display the worker panel data

Template.tsAdminPanel.workerContact = -> Workers.find(contact: true).count()
Template.tsAdminPanel.workerTotal = -> Workers.find().count()

Template.tsAdminAssignments.completedAssts = -> Assignments.find { status: "completed" },
    { sort: submitTime: -1 }
