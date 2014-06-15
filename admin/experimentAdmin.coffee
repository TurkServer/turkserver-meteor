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

  "click .-ts-experiment-logs": ->
    groupId = @_id
    Router.go("/turkserver/logs/#{groupId}/100")

  "click .-ts-stop-experiment": ->
    expId = @_id
    bootbox.confirm "This will end the experiment immediately. Are you sure?", (res) ->
      Meteor.call "ts-admin-stop-experiment", expId if res

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

Template.tsAdminCompletedExperiments.duration = ->
  TurkServer.Util.duration(@endTime - @startTime)

Template.tsAdminCompletedExperiments.numUsers = numUsers

Template.tsAdminLogs.logEntries = -> Logs.find({}, {sort: _timestamp: -1})
Template.tsAdminLogs.entryData = -> _.omit(@, "_id", "_userId", "_groupId", "_timestamp")

Template.tsAdminTreatments.treatments = treatments
Template.tsAdminTreatments.zeroTreatments = -> Treatments.find().count() is 0

Template.tsAdminTreatments.events =
  "click tbody > tr": (e) ->
    Session.set("_tsSelectedTreatmentId", @_id)

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

Template.tsAdminTreatmentConfig.selectedTreatment = ->
  Treatments.findOne Session.get("_tsSelectedTreatmentId")

Template.tsAdminConfigureBatch.events =
  "click .-ts-activate-batch": ->
    Batches.update @_id, $set:
      active: true

  "click .-ts-deactivate-batch": ->
    Batches.update @_id, $set:
      active: false

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
    treatmentName = "" + (@name || @) # In case the treatment is gone
    Batches.update Session.get("_tsSelectedBatchId"),
      $pull: { treatments:  treatmentName }

  "click .-ts-add-batch-treatment": (e, tmpl) ->
    e.preventDefault()
    treatment = UI.getElementData(tmpl.find(":selected"))
    return unless treatment?
    Batches.update @_id,
      $addToSet: { treatments: treatment.name }

Template.tsAdminBatchEditTreatments.allTreatments = treatments

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
