Doobie = new Meteor.Collection("experiment_test")

treatment = undefined
group = undefined

contextHandler = ->
  treatment = @treatment
  group = @group

insertHandler = ->
  Doobie.insert
    foo: "bar"

  # Test deferred insert
  Meteor.defer ->
    Doobie.insert
      bar: "baz"

Partitioner.partitionCollection Doobie

TurkServer.initialize contextHandler
TurkServer.initialize insertHandler

# Ensure batch exists
Batches.upsert "expBatch", $set: {}

# Create a dummy assignment
expTestUserId = "expUser"
expTestWorkerId = "expWorker"
Meteor.users.upsert expTestUserId,
  $set: { workerId: expTestWorkerId }

# Set up a treatment for testing
TurkServer.ensureTreatmentExists
  name: "fooTreatment"
  fooProperty: "bar"

# These instances are created once for each set of tests, then discarded
serverInstanceId = null
secondInstanceId = null

withCleanup = TestUtils.getCleanupWrapper
  before: ->
    # Clear contents of collection
    # TODO should be able to use .direct.remove here but it seems to be currently broken:
    # https://github.com/matb33/meteor-collection-hooks/issues/3#issuecomment-42878962
    Partitioner.directOperation ->
      Doobie.remove {}

    # Set user state to be in lobby
    Meteor.users.update expTestUserId,
      $set: "turkserver.state": "lobby"

    # Reset assignments
    Assignments.upsert {
        batchId: "expBatch"
        hitId: "expHIT"
        assignmentId: "expAsst"
        workerId: expTestWorkerId
      }, {
        $set: status: "assigned"
        $unset: instances: null
      }

    # Delete any log entries generated
    Logs.remove
      _groupId: serverInstanceId

    # Delete any data stored in instances
    # TODO: can probably improve this and not use a global variable
    Experiments.update serverInstanceId,
      $unset:
        startTime: null
        endTime: null
        users: null
    Experiments.update secondInstanceId,
      $unset:
        startTime: null
        endTime: null
        users: null

    # Clear user group
    Partitioner.clearUserGroup(expTestUserId)
  after: -> # Can't use this for async

lastLog = (groupId) -> Logs.findOne({_groupId: groupId}, {sort: timestamp: -1})

Tinytest.add "experiment - batch - creation and retrieval", withCleanup (test) ->
  # First get should create, second get should return same object
  # TODO: this test will only run as intended on the first try
  batch = TurkServer.Batch.getBatch("expBatch")
  batch2 = TurkServer.Batch.getBatch("expBatch")

  test.equal batch2, batch

Tinytest.add "experiment - instance - throws error if doesn't exist", withCleanup (test) ->
  test.throws ->
    TurkServer.Instance.getInstance("yabbadabbadoober")

Tinytest.add "experiment - instance - create", withCleanup (test) ->
  batch = TurkServer.Batch.getBatch("expBatch")

  # Create a new id for this batch of tests
  serverInstanceId = Random.id()

  instance = batch.createInstance([ "fooTreatment" ], {_id: serverInstanceId})
  test.instanceOf(instance, TurkServer.Instance)

  instanceData = Experiments.findOne(serverInstanceId)
  test.equal instanceData.batchId, "expBatch"
  test.instanceOf instanceData.startTime, Date

  # Test that create meta event was recorded in log
  logEntry = lastLog(serverInstanceId)
  test.isTrue logEntry
  test.equal logEntry?._meta, "created"

  # Getting the instance again should get the same one
  inst2 = TurkServer.Instance.getInstance(serverInstanceId)
  test.equal inst2, instance

  secondInstanceId = Random.id()
  instance = batch.createInstance([ "fooTreatment" ], {_id: secondInstanceId })

Tinytest.add "experiment - instance - setup context", withCleanup (test) ->
  treatment = undefined
  group = undefined
  instance = TurkServer.Instance.getInstance(serverInstanceId)
  # For this test to work, it better be the only setup on the page
  instance.setup()

  test.equal instance.batch(), TurkServer.Batch.getBatch("expBatch")

  test.isTrue treatment
  test.isTrue "fooTreatment" in treatment.treatments,
  test.equal treatment.fooProperty, "bar"
  test.equal group, serverInstanceId

  # Check that the init _meta event was logged with treatment info
  logEntry = lastLog(serverInstanceId)
  test.isTrue logEntry
  test.equal logEntry?._meta, "initialized"
  test.equal logEntry?.treatmentData, treatment

Tinytest.add "experiment - instance - teardown and log", withCleanup (test) ->
  instance = TurkServer.Instance.getInstance(serverInstanceId)

  instance.teardown()

  logEntry = lastLog(serverInstanceId)
  test.isTrue logEntry
  test.equal logEntry?._meta, "teardown"

Tinytest.add "experiment - instance - global group", withCleanup (test) ->
  Partitioner.bindGroup serverInstanceId, ->
    Doobie.insert
      foo: "bar"

  stuff = Partitioner.directOperation ->
    Doobie.find().fetch()

  test.length stuff, 1

  test.equal stuff[0].foo, "bar"
  test.equal stuff[0]._groupId, serverInstanceId

Tinytest.add "experiment - instance - teardown", withCleanup (test) ->
  instance = TurkServer.Instance.getInstance(serverInstanceId)
  instance.teardown()

  instanceData = Experiments.findOne(serverInstanceId)
  test.instanceOf instanceData.endTime, Date

Tinytest.add "experiment - instance - reject adding user to ended instance", withCleanup (test) ->
  instance = TurkServer.Instance.getInstance(serverInstanceId)
  instance.teardown()

  test.throws ->
    asst = TurkServer.Assignment.getCurrentUserAssignment(expTestUserId)
    instance.addAssignment(asst)

  user = Meteor.users.findOne(expTestUserId)
  asstData = Assignments.findOne(workerId: expTestWorkerId, status: "assigned")

  test.length instance.users(), 0
  test.equal user.turkserver.state, "lobby"

  test.isFalse asstData.instances

Tinytest.add "experiment - instance - addAssignment records instance id", withCleanup (test) ->
  instance = TurkServer.Instance.getInstance(serverInstanceId)
  asst = TurkServer.Assignment.getCurrentUserAssignment(expTestUserId)
  instance.addAssignment(asst)

  user = Meteor.users.findOne(expTestUserId)
  asstData = Assignments.findOne(workerId: expTestWorkerId, status: "assigned")

  test.isTrue expTestUserId in instance.users()
  test.equal user.turkserver.state, "experiment"
  test.instanceOf(asstData.instances, Array)

  test.isTrue asstData.instances[0]
  test.equal asstData.instances[0].id, serverInstanceId
  test.isTrue asstData.instances[0].joinTime

Tinytest.add "experiment - instance - user disconnect and reconnect", withCleanup (test) ->
  instance = TurkServer.Instance.getInstance(serverInstanceId)
  asst = TurkServer.Assignment.getCurrentUserAssignment(expTestUserId)
  instance.addAssignment(asst)

  TestUtils.connCallbacks.userDisconnect
    userId: expTestUserId

  asstData = Assignments.findOne(workerId: expTestWorkerId, status: "assigned")

  # TODO ensure the accounting here is done correctly
  discTime = null

  test.isTrue asstData.instances[0]
  test.isTrue asstData.instances[0].joinTime
  test.isTrue (discTime = asstData.instances[0].lastDisconnect)

  TestUtils.connCallbacks.userReconnect
    userId: expTestUserId

  asstData = Assignments.findOne(workerId: expTestWorkerId, status: "assigned")
  test.isFalse asstData.instances[0].lastDisconnect
  # We don't know the exact length of disconnection, but make sure it's in the right ballpark
  test.isTrue asstData.instances[0].disconnectedTime > 0
  test.isTrue asstData.instances[0].disconnectedTime < Date.now() - discTime

Tinytest.add "experiment - instance - user idle and re-activate", withCleanup (test) ->
  instance = TurkServer.Instance.getInstance(serverInstanceId)
  asst = TurkServer.Assignment.getCurrentUserAssignment(expTestUserId)
  instance.addAssignment(asst)

  idleTime = new Date()

  TestUtils.connCallbacks.userIdle
    userId: expTestUserId
    lastActivity: idleTime

  asstData = Assignments.findOne(workerId: expTestWorkerId, status: "assigned")
  test.isTrue asstData.instances[0]
  test.isTrue asstData.instances[0].joinTime
  test.equal asstData.instances[0].lastIdle, idleTime

  offset = 1000
  activeTime = new Date(idleTime.getTime() + offset)

  TestUtils.connCallbacks.userActive
    userId: expTestUserId
    lastActivity: activeTime

  asstData = Assignments.findOne(workerId: expTestWorkerId, status: "assigned")
  test.isFalse asstData.instances[0].lastIdle
  test.equal asstData.instances[0].idleTime, offset

  # Another bout of inactivity
  secondIdleTime = new Date(activeTime.getTime() + 5000)
  secondActiveTime = new Date(secondIdleTime.getTime() + offset)

  TestUtils.connCallbacks.userIdle
    userId: expTestUserId
    lastActivity: secondIdleTime

  TestUtils.connCallbacks.userActive
    userId: expTestUserId
    lastActivity: secondActiveTime

  asstData = Assignments.findOne(workerId: expTestWorkerId, status: "assigned")
  test.isFalse asstData.instances[0].lastIdle
  test.equal asstData.instances[0].idleTime, offset + offset

Tinytest.add "experiment - instance - user disconnect while idle", withCleanup (test) ->
  instance = TurkServer.Instance.getInstance(serverInstanceId)
  asst = TurkServer.Assignment.getCurrentUserAssignment(expTestUserId)
  instance.addAssignment(asst)

  idleTime = new Date()

  TestUtils.connCallbacks.userIdle
    userId: expTestUserId
    lastActivity: idleTime

  TestUtils.connCallbacks.userDisconnect
    userId: expTestUserId

  asstData = Assignments.findOne(workerId: expTestWorkerId, status: "assigned")
  test.isTrue asstData.instances[0].joinTime
  # Check that idle fields exist
  test.isFalse asstData.instances[0].lastIdle
  test.isTrue asstData.instances[0].idleTime
  # Check that disconnect fields exist
  test.isTrue asstData.instances[0].lastDisconnect

Tinytest.add "experiment - instance - idleness is cleared on reconnection", withCleanup (test) ->
  instance = TurkServer.Instance.getInstance(serverInstanceId)
  asst = TurkServer.Assignment.getCurrentUserAssignment(expTestUserId)
  instance.addAssignment(asst)

  idleTime = new Date()

  TestUtils.connCallbacks.userDisconnect
    userId: expTestUserId

  TestUtils.connCallbacks.userIdle
    userId: expTestUserId
    lastActivity: idleTime

  TestUtils.sleep(100)

  TestUtils.connCallbacks.userReconnect
    userId: expTestUserId

  asstData = Assignments.findOne(workerId: expTestWorkerId, status: "assigned")

  test.isTrue asstData.instances[0].joinTime
  # Check that idleness was not counted
  test.isFalse asstData.instances[0].lastIdle
  test.isFalse asstData.instances[0].idleTime
  # Check that disconnect fields exist
  test.isFalse asstData.instances[0].lastDisconnect
  test.isTrue asstData.instances[0].disconnectedTime

Tinytest.add "experiment - instance - teardown while disconnected", withCleanup (test) ->
  instance = TurkServer.Instance.getInstance(serverInstanceId)
  asst = TurkServer.Assignment.getCurrentUserAssignment(expTestUserId)
  instance.addAssignment(asst)

  TestUtils.connCallbacks.userDisconnect
    userId: expTestUserId

  discTime = null
  asstData = Assignments.findOne(workerId: expTestWorkerId, status: "assigned")
  test.isTrue(discTime = asstData.instances[0].lastDisconnect)

  instance.teardown()

  asstData = Assignments.findOne(workerId: expTestWorkerId, status: "assigned")

  test.isTrue asstData.instances[0].leaveTime
  test.isFalse asstData.instances[0].lastDisconnect
  # We don't know the exact length of disconnection, but make sure it's in the right ballpark
  test.isTrue asstData.instances[0].disconnectedTime > 0
  test.isTrue asstData.instances[0].disconnectedTime < Date.now() - discTime

Tinytest.add "experiment - instance - teardown while idle", withCleanup (test) ->
  instance = TurkServer.Instance.getInstance(serverInstanceId)
  asst = TurkServer.Assignment.getCurrentUserAssignment(expTestUserId)
  instance.addAssignment(asst)

  idleTime = new Date()

  TestUtils.connCallbacks.userIdle
    userId: expTestUserId
    lastActivity: idleTime

  instance.teardown()

  asstData = Assignments.findOne(workerId: expTestWorkerId, status: "assigned")

  test.isTrue asstData.instances[0].leaveTime
  test.isFalse asstData.instances[0].lastIdle
  test.isTrue asstData.instances[0].idleTime

Tinytest.add "experiment - instance - teardown and join second instance", withCleanup (test) ->
  instance = TurkServer.Instance.getInstance(serverInstanceId)
  asst = TurkServer.Assignment.getCurrentUserAssignment(expTestUserId)
  instance.addAssignment(asst)

  instance.teardown()

  user = Meteor.users.findOne(expTestUserId)
  asstData = Assignments.findOne(workerId: expTestWorkerId, status: "assigned")

  test.isTrue expTestUserId in instance.users() # Shouldn't have been removed
  test.equal user.turkserver.state, "lobby"
  test.instanceOf(asstData.instances, Array)

  test.isTrue asstData.instances[0]
  test.equal asstData.instances[0].id, serverInstanceId
  test.isTrue asstData.instances[0].joinTime
  test.isTrue asstData.instances[0].leaveTime

  instance2 = TurkServer.Instance.getInstance(secondInstanceId)

  instance2.addAssignment(asst)

  user = Meteor.users.findOne(expTestUserId)
  test.equal user.turkserver.state, "experiment"

  instance2.teardown()

  user = Meteor.users.findOne(expTestUserId)
  asstData = Assignments.findOne(workerId: expTestWorkerId, status: "assigned")

  test.isTrue expTestUserId in instance2.users() # Shouldn't have been removed
  test.equal user.turkserver.state, "lobby"
  test.instanceOf(asstData.instances, Array)

  # Make sure array-based updates worked
  test.isTrue asstData.instances[1]
  test.equal asstData.instances[1].id, secondInstanceId
  test.notEqual asstData.instances[0].joinTime, asstData.instances[1].joinTime
  test.notEqual asstData.instances[0].leaveTime, asstData.instances[1].leaveTime

# TODO clean up assignments if they affect other tests



