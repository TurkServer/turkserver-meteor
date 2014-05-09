if Meteor.isServer
  # Ensure batch exists
  Batches.upsert "expClientBatch", $set: {}

  # Set up a treatment for testing
  TurkServer.ensureTreatmentExists
    name: "expClientTreatment"
    fooProperty: "bar"

    # Add a user to this group upon login, for client tests below
  Accounts.onLogin (info) ->
    userId = info.user._id
    Partitioner.clearUserGroup(userId) # Remove any previous user group

    batch = TurkServer.Batch.getBatch("expClientBatch")
    batch.createInstance(["expClientTreatment"]).addUser(userId)

if Meteor.isClient
  Tinytest.addAsync "experiment - client - received experiment and treatment", (test, next) ->
    treatment = null

    verify = ->
      console.info "Got treatment ", treatment

      test.isTrue Experiments.findOne()
      test.isTrue treatment

      # No _id or name sent over the wire
      test.isFalse treatment._id
      test.isFalse treatment.name
      test.equal treatment.fooProperty, "bar"
      next()

    fail = ->
      test.fail()
      next()

    # Poll until treatment data arrives
    simplePoll (->
      treatment = TurkServer.treatment()
      return true if treatment.treatments.length
    ), verify, fail, 2000

