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

    # Delete any data stored in instances
    # TODO: can probably improve this and not use a global variable
    Experiments.update serverInstanceId,
      $unset: users: null
    Experiments.update secondInstanceId,
      $unset: users: null

    # Clear user group
    Partitioner.clearUserGroup(expTestUserId)
  after: -> # Can't use this for async

Tinytest.add "experiment - batch - creation and retrieval", withCleanup (test) ->
  # First get should create, second get should return same object
  # TODO: this test will only run as intended on the first try
  batch = TurkServer.Batch.getBatch("expBatch")
  batch2 = TurkServer.Batch.getBatch("expBatch")

  test.equal batch2, batch

Tinytest.add "experiment - instance - create", withCleanup (test) ->
  batch = TurkServer.Batch.getBatch("expBatch")

  # Create a new id for this batch of tests
  serverInstanceId = Random.id()

  instance = batch.createInstance([ "fooTreatment" ], {_id: serverInstanceId})
  test.instanceOf(instance, TurkServer.Instance)

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
  test.equal treatment[0].name, "fooTreatment"
  test.equal treatment[0].fooProperty, "bar"
  test.equal group, serverInstanceId

Tinytest.add "experiment - instance - global group", withCleanup (test) ->
  Partitioner.bindGroup serverInstanceId, ->
    Doobie.insert
      foo: "bar"

  stuff = Partitioner.directOperation ->
    Doobie.find().fetch()

  test.length stuff, 1

  test.equal stuff[0].foo, "bar"
  test.equal stuff[0]._groupId, serverInstanceId

Tinytest.add "experiment - instance - addUser records instance id", withCleanup (test) ->
  instance = TurkServer.Instance.getInstance(serverInstanceId)
  instance.addUser(expTestUserId)

  user = Meteor.users.findOne(expTestUserId)
  asst = Assignments.findOne(workerId: expTestWorkerId, status: "assigned")

  test.isTrue expTestUserId in instance.users()
  test.equal user.turkserver.state, "experiment"
  test.instanceOf(asst.instances, Array)

  test.isTrue asst.instances[0]
  test.equal asst.instances[0].id, serverInstanceId
  test.isTrue asst.instances[0].joinTime

Tinytest.add "experiment - instance - user disconnect and reconnect", withCleanup (test) ->
  instance = TurkServer.Instance.getInstance(serverInstanceId)
  instance.addUser(expTestUserId)

  TestUtils.connCallbacks.userDisconnect
    userId: expTestUserId

  asst = Assignments.findOne(workerId: expTestWorkerId, status: "assigned")

  discTime = null

  test.isTrue asst.instances[0]
  test.isTrue asst.instances[0].joinTime
  test.isTrue (discTime = asst.instances[0].lastDisconnect)

  TestUtils.connCallbacks.userReconnect
    userId: expTestUserId

  asst = Assignments.findOne(workerId: expTestWorkerId, status: "assigned")

  test.isFalse asst.instances[0].lastDisconnect
  test.isTrue asst.instances[0].disconnectedTime

Tinytest.add "experiment - instance - teardown while disconnected", withCleanup (test) ->
  instance = TurkServer.Instance.getInstance(serverInstanceId)
  instance.addUser(expTestUserId)

  TestUtils.connCallbacks.userDisconnect
    userId: expTestUserId

  instance.teardown()

  asst = Assignments.findOne(workerId: expTestWorkerId, status: "assigned")

  test.isFalse asst.instances[0].lastDisconnect
  test.isTrue asst.instances[0].leaveTime
  test.isTrue asst.instances[0].disconnectedTime

Tinytest.add "experiment - instance - teardown and join second instance", withCleanup (test) ->
  instance = TurkServer.Instance.getInstance(serverInstanceId)
  instance.addUser(expTestUserId)

  instance.teardown()

  user = Meteor.users.findOne(expTestUserId)
  asst = Assignments.findOne(workerId: expTestWorkerId, status: "assigned")

  test.isTrue expTestUserId in instance.users() # Shouldn't have been removed
  test.equal user.turkserver.state, "lobby"
  test.instanceOf(asst.instances, Array)

  test.isTrue asst.instances[0]
  test.equal asst.instances[0].id, serverInstanceId
  test.isTrue asst.instances[0].joinTime
  test.isTrue asst.instances[0].leaveTime

  instance2 = TurkServer.Instance.getInstance(secondInstanceId)

  instance2.addUser(expTestUserId)

  user = Meteor.users.findOne(expTestUserId)
  test.equal user.turkserver.state, "experiment"

  instance2.teardown()

  user = Meteor.users.findOne(expTestUserId)
  asst = Assignments.findOne(workerId: expTestWorkerId, status: "assigned")

  test.isTrue expTestUserId in instance2.users() # Shouldn't have been removed
  test.equal user.turkserver.state, "lobby"
  test.instanceOf(asst.instances, Array)

  # Make sure array-based updates worked
  test.isTrue asst.instances[1]
  test.equal asst.instances[1].id, secondInstanceId
  test.notEqual asst.instances[0].joinTime, asst.instances[1].joinTime
  test.notEqual asst.instances[0].leaveTime, asst.instances[1].leaveTime

# TODO clean up assignments if they affect other tests

Tinytest.add "experiment - instance - throws error if doesn't exist", withCleanup (test) ->
  test.throws ->
    TurkServer.Instance.getInstance("yabbadabbadoober")


