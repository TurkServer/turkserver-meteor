Template.tsAdminActiveBatches.events =
  "click .-ts-test-batch": ->
    bootbox.prompt "Enter a name for this batch", (res) ->
      return unless res?
      Batches.insert
        name: res
        desc: "A test batch."
        active: true
  "click .-ts-new-batch": ->
    # TODO decide what we are doing here
    bootbox.alert "Not implemented yet."
  "click .-ts-retire-batch": ->
    Batches.update @_id, $set:
      active: false

Template.tsAdminActiveBatches.activeBatch = -> Batches.findOne(active: true)

Template.tsAdminBatchList.batches = -> Batches.find()
Template.tsAdminBatchList.zeroBatches = -> Batches.find().count() is 0
