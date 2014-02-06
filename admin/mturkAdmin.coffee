quals = -> Qualifications.find()

Template.tsAdminMTurk.selectedHITType = -> HITTypes.findOne Session.get("_tsSelectedHITType")

Template.tsAdminHitTypes.events =
  "click tr": -> Session.set("_tsSelectedHITType", @_id)

Template.tsAdminHitTypes.hitTypes = -> HITTypes.find()
Template.tsAdminHitTypes.selectedClass = ->
  if Session.equals("_tsSelectedHITType", @_id) then "info" else ""

Template.tsAdminViewHitType.events =
  "click .-ts-register-hittype": ->
    Meteor.call "ts-admin-register-hittype", @_id, (err, res) ->
      bootbox.alert(err.reason) if err

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
