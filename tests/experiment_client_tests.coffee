if Meteor.isServer

  # Set up a treatment for testing
  TurkServer.ensureTreatmentExists
    name: "expWorldTreatment"
    fooProperty: "bar"

  TurkServer.ensureTreatmentExists
    name: "expUserTreatment"
    foo2: "baz"

  # Some functions to make sure things are set up for the client login
  Accounts.validateLoginAttempt (info) ->
    return unless info.allowed # Don't handle if login is being rejected
    userId = info.user._id

    Partitioner.clearUserGroup(userId) # Remove any previous user group
    return true

  Accounts.onLogin (info) ->
    userId = info.user._id

    # Worker and assignment should have already been created at this point
    asst = TurkServer.Assignment.getCurrentUserAssignment(userId)

    # Reset assignment for this worker
    Assignments.upsert asst.asstId,
      $unset: instances: null,
      $unset: treatments: null

    asst.getBatch().createInstance(["expWorldTreatment"]).addAssignment(asst)

    asst.addTreatment("expUserTreatment")

    Meteor._debug "Remote client logged in"

  Meteor.methods
    getAssignmentData: ->
      userId = Meteor.userId()
      throw new Meteor.Error(500, "Not logged in") unless userId
      workerId = Meteor.users.findOne(userId).workerId
      return Assignments.findOne({workerId, status: "assigned"})

    setAssignmentPayment: (amount) ->
      TurkServer.Assignment.currentAssignment().setPayment(amount);
      return

    setAssignmentInstanceData: (arr) ->
      selector =
        workerId: Meteor.user().workerId
        status: "assigned"

      unless Assignments.update(selector, $set: {instances: arr}) > 0
        throw new Meteor.Error(400, "Could not find assignment to update")
      return

    endAssignmentInstance: (returnToLobby) ->
      TurkServer.Instance.currentInstance().teardown(returnToLobby)
      return

if Meteor.isClient
  tol = 20 # range in ms that we can be off in adjacent cols
  big_tol = 500 # max range we tolerate in a round trip to the server (async method)

  Tinytest.addAsync "experiment - client - login and creation of assignment metadata", (test, next) ->
    InsecureLogin.ready ->
      test.isTrue Meteor.userId()
      next()

  Tinytest.addAsync "experiment - client - IP address saved", (test, next) ->
    returned = false
    Meteor.call "getAssignmentData", (err, res) ->
      returned = true
      test.isFalse err
      console.log "Got assignment data", JSON.stringify(res)

      test.isTrue res?.ipAddr?[0]
      test.equal res?.userAgent?[0], navigator.userAgent unless Package['test-in-console']?

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

      # Test world-level treatment
      # No _id or name sent over the wire
      worldTreatment = TurkServer.treatment("expWorldTreatment")
      test.isFalse worldTreatment._id
      test.isTrue worldTreatment.name
      test.equal worldTreatment.fooProperty, "bar"

      # Test user-level treatment
      userTreatment = TurkServer.treatment("expUserTreatment")
      test.isFalse userTreatment._id
      test.isTrue userTreatment.name
      test.equal userTreatment.foo2, "baz"

      next()

    fail = ->
      test.fail()
      next()

    # Poll until both treatments arrives
    simplePoll (->
      treatment = TurkServer.treatment()
      return true if treatment.treatments.length
    ), verify, fail, 2000

  Tinytest.addAsync "experiment - client - current payment variable", (test, next) ->
    amount = 0.42

    Meteor.call "setAssignmentPayment", amount, (err, res) ->
      test.equal TurkServer.currentPayment(), amount
      next()

  Tinytest.addAsync "experiment - client - assignment metadata and local time vars", (test, next) ->
    asstData = null

    verify = ->
      console.info "Got assignmentData ", asstData

      test.isTrue asstData.instances
      test.isTrue asstData.instances[0]

      test.isTrue TurkServer.Timers.joinedTime() > 0
      test.equal TurkServer.Timers.idleTime(), 0
      test.equal TurkServer.Timers.disconnectedTime(), 0

      test.isTrue Math.abs(TurkServer.Timers.activeTime() - TurkServer.Timers.joinedTime()) < 10

      next()

    fail = ->
      test.fail()
      next()

    # Poll until treatment data arrives
    simplePoll (->
      asstData = Assignments.findOne()
      return true if asstData?
    ), verify, fail, 2000

  Tinytest.addAsync "experiment - client - no time fields", (test, next) ->
    fields = [
      {
        id: TurkServer.group()
        joinTime: new Date(TimeSync.serverTime())
      }
    ]

    Meteor.call "setAssignmentInstanceData", fields, (err, res) ->
      test.isFalse err
      Deps.flush() # Help out the emboxed value thingies

      test.equal TurkServer.Timers.idleTime(), 0
      test.equal TurkServer.Timers.disconnectedTime(), 0

      joinedTime = TurkServer.Timers.joinedTime()
      activeTime = TurkServer.Timers.activeTime()

      test.isTrue joinedTime >= 0
      test.isTrue joinedTime < big_tol

      test.isTrue activeTime >= 0

      test.equal UI._globalHelpers.tsIdleTime(), "0:00:00"
      test.equal UI._globalHelpers.tsDisconnectedTime(), "0:00:00"

      next()

  Tinytest.addAsync "experiment - client - joined time computation", (test, next) ->
    fields = [
      {
        id: TurkServer.group()
        joinTime: new Date(TimeSync.serverTime() - 3000)
        idleTime: 1000
        disconnectedTime: 2000
      }
    ]

    Meteor.call "setAssignmentInstanceData", fields, (err, res) ->
      test.isFalse err
      Deps.flush() # Help out the emboxed value thingies

      test.equal TurkServer.Timers.idleTime(), 1000
      test.equal TurkServer.Timers.disconnectedTime(), 2000

      joinedTime = TurkServer.Timers.joinedTime()
      activeTime = TurkServer.Timers.activeTime()

      test.isTrue joinedTime >= 3000
      test.isTrue joinedTime < 3000 + big_tol
      test.isTrue Math.abs(activeTime + 3000 - joinedTime) < tol
      test.isTrue activeTime >= 0

      test.equal UI._globalHelpers.tsIdleTime(), "0:00:01"
      test.equal UI._globalHelpers.tsDisconnectedTime(), "0:00:02"

      next()

  Tinytest.addAsync "experiment - client - instance ended state", (test, next) ->
    # In experiment. not ended
    test.isTrue TurkServer.inExperiment()
    test.isFalse TurkServer.instanceEnded()

    Meteor.call "endAssignmentInstance", false, (err, res) ->
      test.isTrue TurkServer.inExperiment()
      test.isTrue TurkServer.instanceEnded()

      next()

  ###
    Next test edits instance fields, so client APIs may break state
  ###

  Tinytest.addAsync "experiment - client - selects correct instance of multiple", (test, next) ->
    fields = [
      {
        id: Random.id()
        joinTime: new Date(TimeSync.serverTime() - 3600*1000)
        idleTime: 3000
        disconnectedTime: 5000
      },
      {
        id: TurkServer.group()
        joinTime: new Date(TimeSync.serverTime() - 5000)
        idleTime: 1000
        disconnectedTime: 2000
      }
    ]

    Meteor.call "setAssignmentInstanceData", fields, (err, res) ->
      test.isFalse err
      Deps.flush() # Help out the emboxed value thingies

      test.equal TurkServer.Timers.idleTime(), 1000
      test.equal TurkServer.Timers.disconnectedTime(), 2000

      joinedTime = TurkServer.Timers.joinedTime()
      activeTime = TurkServer.Timers.activeTime()

      test.isTrue joinedTime >= 5000
      test.isTrue joinedTime < 5000 + big_tol

      test.isTrue Math.abs(activeTime + 3000 - joinedTime) < tol
      test.isTrue activeTime >= 0 # Should not be negative

      test.equal UI._globalHelpers.tsIdleTime(), "0:00:01"
      test.equal UI._globalHelpers.tsDisconnectedTime(), "0:00:02"

      next()

  # TODO: add a test for submitting HIT and verify that resume token is removed
