activeBatch = -> Batches.findOne(active: true)
treatments = -> Treatments.find()

Template.tsAdminExperiments.events =
  "click .-ts-watch-experiment": ->
    groupId = @_id
    currentRoute = Router.current()
    # Go to new route to avoid triggering leaving group
    Router.go(Meteor.settings?.public?.turkserver?.watchRoute || "/")

    Meteor.call "ts-admin-join-group", groupId, (err, res) ->
      return unless err
      Router.go(currentRoute)
      bootbox.alert(err.reason)

  "click .-ts-stop-experiment": ->
    expId = @_id
    bootbox.confirm "This will end the experiment immediately. Are you sure?", (res) ->
      Meteor.call "ts-admin-stop-experiment", expId if res

Template.tsAdminExperiments.activeBatch = activeBatch

numUsers = -> @users?.length

Template.tsAdminActiveExperiments.experiments = ->
  Experiments.find
    endTime: {$exists: false}
  ,
    sort: { startTime: 1 }

Template.tsAdminActiveExperiments.numUsers = numUsers

Template.tsAdminCompletedExperiments.experiments = ->
  Experiments.find
    endTime: {$exists: true}
  ,
    sort: { startTime: 1 }

Template.tsAdminCompletedExperiments.duration = -> Util.duration(@endTime - @startTime)

Template.tsAdminCompletedExperiments.numUsers = numUsers

Template.tsAdminTreatments.treatments = treatments
Template.tsAdminTreatments.zeroTreatments = -> Treatments.find().count() is 0

Template.tsAdminTreatments.events =
  "click .-ts-delete-treatment": ->
    Meteor.call "ts-delete-treatment", @_id, (err, res) ->
      bootbox.alert(err.message) if err

Template.tsAdminNewTreatment.events =
  "submit form": (e, tmpl) ->
    e.preventDefault()
    el = tmpl.find("input[name=name]")
    name = el.value
    el.value = ""

    unless name
      bootbox.alert "Enter a non-empty string."
      return

    Treatments.insert
      name: name
    , (e) -> bootbox.alert(e.message) if e

Template.tsAdminActiveBatches.events =
  "click .-ts-retire-batch": ->
    Batches.update @_id, $set:
      active: false

Template.tsAdminActiveBatches.activeBatch = activeBatch

Template.tsAdminConfigureBatch.events =
  "click .-ts-activate-batch": (e) ->
    unless @treatmentIds?.length > 0
      bootbox.alert "Select at least one treatment to activate this batch."
      return
    Meteor.call "ts-admin-activate-batch", @_id

Template.tsAdminConfigureBatch.selectedBatch = ->
  Batches.findOne(Session.get("_tsSelectedBatchId"))

Template.tsAdminBatchEditDesc.rendered = ->
  container = @$('div.editable')
  grabValue = -> $.trim container.text() # Always get reactively updated value
  container.editable
    value: grabValue
    display: -> # Never set text; have Meteor update to preserve reactivity
    success: (response, newValue) =>
      Batches.update @data._id,
        $set: { desc: newValue }
      # Thinks it knows the value, but it actually doesn't - grab a fresh value each time
      Meteor.defer -> container.data('editableContainer').formOptions.value = grabValue
      return # The value of this function matters
  return

Template.tsAdminBatchEditTreatments.events =
  "click .-ts-remove-batch-treatment": (e, tmpl) ->
    Batches.update Session.get("_tsSelectedBatchId"),
      $pull: { treatmentIds: @_id }
  "click .-ts-add-batch-treatment": (e, tmpl) ->
    e.preventDefault()
    treatment = UI.getElementData(tmpl.find(":selected"))
    return unless treatment._id
    Batches.update @_id,
      $addToSet: { treatmentIds: treatment._id }

Template.tsAdminBatchEditTreatments.treatments = treatments
Template.tsAdminBatchEditTreatments.treatmentName = ->
  Treatments.findOne(""+@)?.name

Template.tsAdminBatchEditGrouping.events =
  "change select": (e, tmpl) ->
    selected = tmpl.find(":selected").value
    Batches.update @_id,
      $set: grouping: selected
  "change input[name=groupVal]": (e) ->
    value = parseInt e.target.value
    return unless value
    Batches.update @_id,
      $set: groupVal: value
  "change input[name=lobby]": (e) ->
    Batches.update @_id,
      $set: lobby: e.target.checked

Template.tsAdminBatchEditGrouping.fixedGroupSize = -> @grouping is "groupSize"
Template.tsAdminBatchEditGrouping.fixedGroupCount = -> @grouping is "groupCount"
Template.tsAdminBatchEditGrouping.lobbyEnabled = -> if @lobby then "with lobby" else "no lobby"

Template.tsAdminConfigureBatch.activatable = ->
  not @active and not Batches.findOne(active: true)

Template.tsAdminBatchList.events =
  "click tbody > tr": (e) ->
    Session.set("_tsSelectedBatchId", @_id)

Template.tsAdminBatchList.batches = -> Batches.find()
Template.tsAdminBatchList.zeroBatches = -> Batches.find().count() is 0

Template.tsAdminBatchList.selectedClass = ->
  if Session.equals("_tsSelectedBatchId", @_id) then "info" else ""

Template.tsAdminAddBatch.events =
  "submit form": (e, tmpl) ->
    e.preventDefault()

    el = tmpl.find("input")
    name = el.value
    return if name is ""

    el.value = ""

    # Default batch settings
    Batches.insert
      name: name
      grouping: "groupSize"
      groupVal: 1
      lobby: true
    , (e) -> bootbox.alert(e.message) if e
