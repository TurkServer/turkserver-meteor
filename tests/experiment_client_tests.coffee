if Meteor.isServer
  # Ensure batch exists
  Batches.upsert "expClientBatch", $set: {}

  # Set up a treatment for testing
  TurkServer.ensureTreatmentExists
    name: "expClientTreatment"
    fooProperty: "bar"

  hitId = "expClientHitId"
  assignmentId = "expClientAssignmentId"
  workerId = "expClientWorkerId"

  # This is just a hack to ensure that a batch and assignment exists for
  # users that login below, so that IP address is stored in the assignment
  # in the onLogin callback
  Accounts.validateLoginAttempt (info) ->
    return unless info.allowed # Don't handle if login is being rejected
    userId = info.user._id
    Partitioner.clearUserGroup(userId) # Remove any previous user group

    # Store workerId for this user
    Meteor.users.update userId,
      $set: { workerId }

    # Reset assignment for this worker
    Assignments.upsert {hitId, assignmentId, workerId},
      $set:
        batchId: "expClientBatch"
        status: "assigned"
      $unset: instances: null

    batch = TurkServer.Batch.getBatch("expClientBatch")
    batch.createInstance(["expClientTreatment"]).addUser(userId)

    Meteor._debug "created assignment for remote client"
    return true

  Meteor.methods
    getAssignmentData: ->
      userId = Meteor.userId()
      throw new Meteor.Error(500, "Not logged in") unless userId
      workerId = Meteor.users.findOne(userId).workerId
      return Assignments.findOne({workerId, status: "assigned"})

if Meteor.isClient
  Tinytest.addAsync "experiment - client - wait for login", (test, next) ->
    InsecureLogin.ready ->
      test.ok()
      next()

  Tinytest.addAsync "experiment - client - IP address saved", (test, next) ->
    returned = false
    Meteor.call "getAssignmentData", (err, res) ->
      returned = true
      test.isFalse err
      console.log "Got assignment data", res
      test.isTrue res.ipAddr
      next()

    fail = ->
      test.fail()
      next()

    simplePoll (-> returned), (->), fail, 2000

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

