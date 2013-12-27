Template.tsAdminTreatments.treatments = -> Treatments.find()
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

Template.tsAdminNewTestBatch.events =
  # Don't let this form submit itself
  "submit form": (e) -> e.preventDefault()

Template.tsAdminNewTestBatch.treatments = -> Treatments.find()

Template.tsAdminActiveBatches.events =
  "click .-ts-test-batch": ->
    unless Treatments.find().count() > 0
      bootbox.alert "Create some treatments first."
      return

    # bootbox.dialog can be used to render Meteor's DOMFragments
    # If we want a title here it will need to be part of the fragment
    $frag = $(Meteor.render Template.tsAdminNewTestBatch)
    bootbox.dialog $frag, [{
      "label" : "Cancel",
      "callback": ->
    }, {
      "label" : "Create",
      "class" : "btn-primary",
      "callback": (e) ->
        $form = $("form.ts-new-test-batch")
        name = $form.find("input[name=name]").val()
        treatment = Spark.getDataContext($form.find(":selected")[0])

        unless name
          bootbox.alert "Batch name cannot be empty."
          return

        Batches.insert
          name: name
          treatmentIds: [ treatment._id ]
          desc: "Test batch."
          active: true
    }]

  "click .-ts-new-batch": ->
    # TODO decide what we are doing here
    bootbox.alert "Not implemented yet."
  "click .-ts-retire-batch": ->
    Batches.update @_id, $set:
      active: false

Template.tsAdminActiveBatches.activeBatch = -> Batches.findOne(active: true)

Template.tsAdminBatchList.events =
  "click .-ts-activate-batch": (e) ->
    Batches.update @_id, $set:
      active: true

Template.tsAdminBatchList.batches = -> Batches.find()
Template.tsAdminBatchList.zeroBatches = -> Batches.find().count() is 0
Template.tsAdminBatchList.treatmentName = -> Treatments.findOne(""+@)?.name
Template.tsAdminBatchList.activatable = ->
  not @active and not Batches.findOne(active: true)
