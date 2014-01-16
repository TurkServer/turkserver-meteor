activeBatch = -> Batches.findOne(active: true)
treatments = -> Treatments.find()

Template.tsAdminExperiments.activeBatch = activeBatch

Template.tsAdminActiveExperiments.events =
  "click .-ts-watch-experiment": ->
    bootbox.prompt "Enter route for the experiment task", (result) ->
      console.log "Joining group not implemented yet."

Template.tsAdminActiveExperiments.experiments = -> Experiments.find()
Template.tsAdminActiveExperiments.treatmentName = -> Treatments.findOne(@treatment)?.name
Template.tsAdminActiveExperiments.numUsers = -> @users?.length
Template.tsAdminActiveExperiments.zeroExperiments = -> Experiments.find().count() is 0

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
    Batches.update @_id, $set:
      active: true

Template.tsAdminConfigureBatch.selectedBatch = ->
  Batches.findOne(Session.get("_tsSelectedBatchId"))

Template.tsAdminBatchEditDesc.rendered = ->
  settings =
    success: (response, newValue) =>
      Batches.update @data._id,
        $set: { desc: newValue }
  $(@find('div.editable:not(.editable-click)')).editable('destroy').editable(settings)

Template.tsAdminBatchEditTreatments.events =
  "click .-ts-remove-batch-treatment": (e, tmpl) ->
    Batches.update Session.get("_tsSelectedBatchId"),
      $pull: { treatmentIds: @_id }
  "click .-ts-add-batch-treatment": (e, tmpl) ->
    e.preventDefault()
    treatment = Spark.getDataContext(tmpl.find(":selected"))
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
