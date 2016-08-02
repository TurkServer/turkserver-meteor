Doobie = new Mongo.Collection("experiment_test")

Partitioner.partitionCollection Doobie

setupContext = undefined
reconnectContext = undefined
disconnectContext = undefined
idleContext = undefined
activeContext = undefined

TurkServer.initialize -> setupContext = @

TurkServer.initialize ->
  Doobie.insert
    foo: "bar"

  # Test deferred insert
  Meteor.defer ->
    Doobie.insert
      bar: "baz"

TurkServer.onConnect -> reconnectContext = this
TurkServer.onDisconnect -> disconnectContext = this
TurkServer.onIdle -> idleContext = this
TurkServer.onActive -> activeContext = this

# Ensure batch exists
batchId = "expBatch"
Batches.upsert { _id: batchId }, { _id: batchId }

# Set up a treatment for testing
TurkServer.ensureTreatmentExists
  name: "fooTreatment"
  fooProperty: "bar"

batch = TurkServer.Batch.getBatch("expBatch")

createAssignment = ->
  workerId = Random.id()
  userId = Accounts.insertUserDoc {}, {
    workerId,
    turkserver: {state: "lobby"} # Created user goes in lobby
  }
  return TurkServer.Assignment.createAssignment
    batchId: "expBatch"
    hitId: Random.id()
    assignmentId: Random.id()
    workerId: workerId
    acceptTime: new Date()
    status: "assigned"

withCleanup = TestUtils.getCleanupWrapper
  before: ->
    # Clear any callback records
    setupContext = undefined
    reconnectContext = undefined
    disconnectContext = undefined
    idleContext = undefined
    activeContext = undefined

  after: ->
    # Delete assignments
    Assignments.remove({ batchId: "expBatch" })
    # Delete generated log entries
    Experiments.find({ batchId: "expBatch" }).forEach (exp) ->
      Logs.remove({_groupId: exp._id})
    # Delete experiments
    Experiments.remove({ batchId: "expBatch" })

    # Clear contents of partitioned collection
    Doobie.direct.remove {}

lastLog = (groupId) -> Logs.findOne({_groupId: groupId}, {sort: _timestamp: -1})

Tinytest.add "experiment - batch - creation and retrieval", withCleanup (test) ->
  # First get should create, second get should return same object
  # TODO: this test will only run as intended on the first try
  batch2 = TurkServer.Batch.getBatch("expBatch")

  test.equal batch2, batch

Tinytest.add "experiment - instance - throws error if doesn't exist", withCleanup (test) ->
  test.throws ->
    TurkServer.Instance.getInstance("yabbadabbadoober")

Tinytest.add "experiment - instance - create", withCleanup (test) ->
  treatments = [ "fooTreatment" ]

  # Create a new id to test specified ID
  serverInstanceId = Random.id()

  instance = batch.createInstance(treatments, {_id: serverInstanceId})
  test.equal(instance.groupId, serverInstanceId)
  test.instanceOf(instance, TurkServer.Instance)

  # Batch and treatments recorded - no start time until someone joins
  instanceData = Experiments.findOne(serverInstanceId)
  test.equal instanceData.batchId, "expBatch"
  test.equal instanceData.treatments, treatments

  test.isFalse instanceData.startTime

  # Test that create meta event was recorded in log
  logEntry = lastLog(serverInstanceId)
  test.isTrue logEntry
  test.equal logEntry?._meta, "created"

  # Getting the instance again should get the same one
  inst2 = TurkServer.Instance.getInstance(serverInstanceId)
  test.equal inst2, instance

Tinytest.add "experiment - instance - setup context", withCleanup (test) ->
  treatments = [ "fooTreatment" ]
  instance = batch.createInstance(treatments)
  TestUtils.sleep(10) # Enforce different log timestamp
  instance.setup()

  test.isTrue setupContext
  treatment = setupContext?.instance.treatment()

  test.equal instance.batch(), TurkServer.Batch.getBatch("expBatch")

  test.isTrue treatment
  test.isTrue "fooTreatment" in treatment.treatments,
  test.equal treatment.fooProperty, "bar"
  test.equal setupContext?.instance.groupId, instance.groupId

  # Check that the init _meta event was logged with treatment info
  logEntry = lastLog(instance.groupId)
  test.isTrue logEntry
  test.equal logEntry?._meta, "initialized"
  test.equal logEntry?.treatmentData, treatment
  test.equal logEntry?.treatmentData.treatments, treatments
  test.equal logEntry?.treatmentData.fooProperty, "bar"

Tinytest.add "experiment - instance - teardown and log", withCleanup (test) ->
  instance = batch.createInstance([])
  instance.setup()
  TestUtils.sleep(10) # Enforce different log timestamp
  instance.teardown()

  logEntry = lastLog(instance.groupId)
  test.isTrue logEntry
  test.equal logEntry?._meta, "teardown"

  instanceData = Experiments.findOne(instance.groupId)
  test.instanceOf instanceData.endTime, Date

Tinytest.add "experiment - instance - get treatment on server", withCleanup (test) ->
  instance = batch.createInstance(["fooTreatment"])

  # Note this only tests world treatments. Assignment treatments have to be
  # tested with the janky client setup.
  instance.bindOperation ->
    treatment = TurkServer.treatment()
    test.equal treatment.treatments[0], "fooTreatment"

  # Undefined outside of an experiment instance
  test.equal TurkServer.treatment(), undefined

Tinytest.add "experiment - instance - global group", withCleanup (test) ->
  instance = batch.createInstance([])
  instance.setup() # Inserts two items

  TestUtils.sleep(100) # Let deferred insert finish

  instance.bindOperation ->
    Doobie.insert
      foo2: "bar"

  stuff = Partitioner.directOperation ->
    Doobie.find().fetch()

  test.length stuff, 3

  # Setup insert
  test.equal stuff[0].foo, "bar"
  test.equal stuff[0]._groupId, instance.groupId
  # Deferred insert
  test.equal stuff[1].bar, "baz"
  test.equal stuff[1]._groupId, instance.groupId
  # Bound insert
  test.equal stuff[2].foo2, "bar"
  test.equal stuff[2]._groupId, instance.groupId

Tinytest.add "experiment - instance - reject adding user to ended instance", withCleanup (test) ->
  instance = batch.createInstance([])
  instance.setup()

  instance.teardown()

  asst = createAssignment()

  test.throws ->
    instance.addAssignment(asst)

  user = Meteor.users.findOne(asst.userId)
  asstData = Assignments.findOne(asst.asstId)

  test.isFalse Partitioner.getUserGroup(asst.userId)
  test.length instance.users(), 0
  test.equal user.turkserver.state, "lobby"

  test.isFalse asstData.instances

Tinytest.add "experiment - instance - addAssignment records start time and instance id", withCleanup (test) ->
  instance = batch.createInstance([])
  instance.setup()

  asst = createAssignment()

  instance.addAssignment(asst)

  user = Meteor.users.findOne(asst.userId)
  asstData = Assignments.findOne(asst.asstId)
  instanceData = Experiments.findOne(instance.groupId)

  test.equal Partitioner.getUserGroup(asst.userId), instance.groupId

  test.isTrue asst.userId in instance.users()
  test.instanceOf instanceData.startTime, Date

  test.equal user.turkserver.state, "experiment"
  test.instanceOf(asstData.instances, Array)

  test.isTrue asstData.instances[0]
  test.equal asstData.instances[0].id, instance.groupId
  test.isTrue asstData.instances[0].joinTime

Tinytest.add "experiment - instance - second addAssignment does not change date", withCleanup (test) ->
  instance = batch.createInstance([])
  instance.setup()

  asst = createAssignment()

  instance.addAssignment(asst)

  instanceData = Experiments.findOne(instance.groupId)
  test.instanceOf instanceData.startTime, Date

  startedDate = instanceData.startTime

  TestUtils.sleep(10)
  # Add a second user
  asst2 = createAssignment()
  instance.addAssignment(asst2)

  instanceData = Experiments.findOne(instance.groupId)
  # Should be the same date as originally
  test.equal instanceData.startTime, startedDate

Tinytest.add "experiment - instance - teardown with returned assignment", withCleanup (test) ->
  instance = batch.createInstance([])
  instance.setup()

  asst = createAssignment()

  instance.addAssignment(asst)

  asst.setReturned()

  instance.teardown() # This should not throw

  user = Meteor.users.findOne(asst.userId)
  asstData = Assignments.findOne(asst.asstId)

  test.isFalse Partitioner.getUserGroup(asst.userId)
  test.isFalse user.turkserver?.state
  test.isTrue asstData.instances[0]
  test.equal asstData.status, "returned"

Tinytest.add "experiment - instance - user disconnect and reconnect", withCleanup (test) ->
  instance = batch.createInstance([])
  instance.setup()

  asst = createAssignment()

  instance.addAssignment(asst)

  TestUtils.connCallbacks.sessionDisconnect
    userId: asst.userId

  test.isTrue disconnectContext
  test.equal disconnectContext?.event, "disconnected"
  test.equal disconnectContext?.instance, instance
  test.equal disconnectContext?.userId, asst.userId

  asstData = Assignments.findOne(asst.asstId)

  # TODO ensure the accounting here is done correctly
  discTime = null

  test.isTrue asstData.instances[0]
  test.isTrue asstData.instances[0].joinTime
  test.isTrue (discTime = asstData.instances[0].lastDisconnect)

  TestUtils.connCallbacks.sessionReconnect
    userId: asst.userId

  test.isTrue reconnectContext
  test.equal reconnectContext?.event, "connected"
  test.equal reconnectContext?.instance, instance
  test.equal reconnectContext?.userId, asst.userId

  asstData = Assignments.findOne(asst.asstId)
  test.isFalse asstData.instances[0].lastDisconnect
  # We don't know the exact length of disconnection, but make sure it's in the right ballpark
  test.isTrue asstData.instances[0].disconnectedTime > 0
  test.isTrue asstData.instances[0].disconnectedTime < Date.now() - discTime

Tinytest.add "experiment - instance - user idle and re-activate", withCleanup (test) ->
  instance = batch.createInstance([])
  instance.setup()

  asst = createAssignment()

  instance.addAssignment(asst)

  idleTime = new Date()

  TestUtils.connCallbacks.sessionIdle
    userId: asst.userId
    lastActivity: idleTime

  test.isTrue idleContext
  test.equal idleContext?.event, "idle"
  test.equal idleContext?.instance, instance
  test.equal idleContext?.userId, asst.userId

  asstData = Assignments.findOne(asst.asstId)
  test.isTrue asstData.instances[0]
  test.isTrue asstData.instances[0].joinTime
  test.equal asstData.instances[0].lastIdle, idleTime

  offset = 1000
  activeTime = new Date(idleTime.getTime() + offset)

  TestUtils.connCallbacks.sessionActive
    userId: asst.userId
    lastActivity: activeTime

  test.isTrue activeContext
  test.equal activeContext?.event, "active"
  test.equal activeContext?.instance, instance
  test.equal activeContext?.userId, asst.userId

  asstData = Assignments.findOne(asst.asstId)
  test.isFalse asstData.instances[0].lastIdle
  test.equal asstData.instances[0].idleTime, offset

  # Another bout of inactivity
  secondIdleTime = new Date(activeTime.getTime() + 5000)
  secondActiveTime = new Date(secondIdleTime.getTime() + offset)

  TestUtils.connCallbacks.sessionIdle
    userId: asst.userId
    lastActivity: secondIdleTime

  TestUtils.connCallbacks.sessionActive
    userId: asst.userId
    lastActivity: secondActiveTime

  asstData = Assignments.findOne(asst.asstId)
  test.isFalse asstData.instances[0].lastIdle
  test.equal asstData.instances[0].idleTime, offset + offset

Tinytest.add "experiment - instance - user disconnect while idle", withCleanup (test) ->
  instance = batch.createInstance([])
  instance.setup()

  asst = createAssignment()

  instance.addAssignment(asst)

  idleTime = new Date()

  TestUtils.connCallbacks.sessionIdle
    userId: asst.userId
    lastActivity: idleTime

  TestUtils.connCallbacks.sessionDisconnect
    userId: asst.userId

  asstData = Assignments.findOne(asst.asstId)
  test.isTrue asstData.instances[0].joinTime
  # Check that idle fields exist
  test.isFalse asstData.instances[0].lastIdle
  test.isTrue asstData.instances[0].idleTime
  # Check that disconnect fields exist
  test.isTrue asstData.instances[0].lastDisconnect

Tinytest.add "experiment - instance - idleness is cleared on reconnection", withCleanup (test) ->
  instance = batch.createInstance([])
  instance.setup()

  asst = createAssignment()

  instance.addAssignment(asst)

  idleTime = new Date()

  TestUtils.connCallbacks.sessionDisconnect
    userId: asst.userId

  TestUtils.connCallbacks.sessionIdle
    userId: asst.userId
    lastActivity: idleTime

  TestUtils.sleep(100)

  TestUtils.connCallbacks.sessionReconnect
    userId: asst.userId

  asstData = Assignments.findOne(asst.asstId)

  test.isTrue asstData.instances[0].joinTime
  # Check that idleness was not counted
  test.isFalse asstData.instances[0].lastIdle
  test.isFalse asstData.instances[0].idleTime
  # Check that disconnect fields exist
  test.isFalse asstData.instances[0].lastDisconnect
  test.isTrue asstData.instances[0].disconnectedTime

Tinytest.add "experiment - instance - teardown while disconnected", withCleanup (test) ->
  instance = batch.createInstance([])
  instance.setup()

  asst = createAssignment()

  instance.addAssignment(asst)

  TestUtils.connCallbacks.sessionDisconnect
    userId: asst.userId

  discTime = null
  asstData = Assignments.findOne(asst.asstId)
  test.isTrue(discTime = asstData.instances[0].lastDisconnect)

  instance.teardown()

  asstData = Assignments.findOne(asst.asstId)

  test.isFalse Partitioner.getUserGroup(asst.userId)

  test.isTrue asstData.instances[0].leaveTime
  test.isFalse asstData.instances[0].lastDisconnect
  # We don't know the exact length of disconnection, but make sure it's in the right ballpark
  test.isTrue asstData.instances[0].disconnectedTime > 0
  test.isTrue asstData.instances[0].disconnectedTime < Date.now() - discTime

Tinytest.add "experiment - instance - teardown while idle", withCleanup (test) ->
  instance = batch.createInstance([])
  instance.setup()

  asst = createAssignment()

  instance.addAssignment(asst)

  idleTime = new Date()

  TestUtils.connCallbacks.sessionIdle
    userId: asst.userId
    lastActivity: idleTime

  instance.teardown()

  asstData = Assignments.findOne(asst.asstId)

  test.isFalse Partitioner.getUserGroup(asst.userId)

  test.isTrue asstData.instances[0].leaveTime
  test.isFalse asstData.instances[0].lastIdle
  test.isTrue asstData.instances[0].idleTime

Tinytest.add "experiment - instance - leave instance after teardown", withCleanup (test) ->
  instance = batch.createInstance([])
  instance.setup()

  asst = createAssignment()

  instance.addAssignment(asst)

  # Immediately disconnect
  TestUtils.connCallbacks.sessionDisconnect
    userId: asst.userId

  instance.teardown(false)

  # Wait a bit to ensure we have the right value; the above should have
  # completed within this interval
  TestUtils.sleep(200)

  # Could do either of the below
  instance.sendUserToLobby(asst.userId)

  asstData = Assignments.findOne(asst.asstId)

  test.isFalse Partitioner.getUserGroup(asst.userId)

  test.isTrue asstData.instances[0].leaveTime
  test.isFalse asstData.instances[0].lastDisconnect
  # We don't know the exact length of disconnection, but make sure it's in the right ballpark
  test.isTrue asstData.instances[0].disconnectedTime > 0
  test.isTrue asstData.instances[0].disconnectedTime < 200

Tinytest.add "experiment - instance - teardown and join second instance", withCleanup (test) ->
  instance = batch.createInstance([])
  instance.setup()

  asst = createAssignment()

  instance.addAssignment(asst)

  instance.teardown()

  user = Meteor.users.findOne(asst.userId)
  asstData = Assignments.findOne(asst.asstId)

  test.isFalse Partitioner.getUserGroup(asst.userId)

  test.isTrue asst.userId in instance.users() # Shouldn't have been removed
  test.equal user.turkserver.state, "lobby"
  test.instanceOf(asstData.instances, Array)

  test.isTrue asstData.instances[0]
  test.equal asstData.instances[0].id, instance.groupId
  test.isTrue asstData.instances[0].joinTime
  test.isTrue asstData.instances[0].leaveTime

  instance2 = batch.createInstance([])
  instance2.setup()

  instance2.addAssignment(asst)

  user = Meteor.users.findOne(asst.userId)

  test.equal Partitioner.getUserGroup(asst.userId), instance2.groupId
  test.equal user.turkserver.state, "experiment"

  instance2.teardown()

  user = Meteor.users.findOne(asst.userId)
  asstData = Assignments.findOne(asst.asstId)

  test.isFalse Partitioner.getUserGroup(asst.userId)

  test.isTrue asst.userId in instance2.users() # Shouldn't have been removed
  test.equal user.turkserver.state, "lobby"
  test.instanceOf(asstData.instances, Array)

  # Make sure array-based updates worked
  test.isTrue asstData.instances[1]
  test.equal asstData.instances[1].id, instance2.groupId
  test.notEqual asstData.instances[0].joinTime, asstData.instances[1].joinTime
  test.notEqual asstData.instances[0].leaveTime, asstData.instances[1].leaveTime
