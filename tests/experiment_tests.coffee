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
Treatments.upsert {name: "fooTreatment"},
  $set:
    fooProperty: "bar"

withCleanup = TestUtils.getCleanupWrapper
  before: ->
    # Clear contents of collection
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
    # Clear user group
    Partitioner.clearUserGroup(expTestUserId)
after: -> # Can't use this for async

serverInstanceId = null

Tinytest.addAsync "experiment - instance - create", withCleanup (test, next) ->
  batch = TurkServer.Batch.getBatch("expBatch")

  # Create a new id for this batch of tests
  serverInstanceId = Random.id()

  instance = batch.createInstance([ "fooTreatment" ], {_id: serverInstanceId})
  test.isTrue(instance instanceof TurkServer.Instance)

  # Getting the instance again should get the same one
  inst2 = TurkServer.Instance.getInstance(serverInstanceId)
  test.equal inst2, instance

  next()

Tinytest.addAsync "experiment - instance - setup context", withCleanup (test, next) ->
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
  next()

Tinytest.addAsync "experiment - instance - global group", withCleanup (test, next) ->
  Partitioner.bindGroup serverInstanceId, ->
    Doobie.insert
      foo: "bar"

  stuff = Partitioner.directOperation ->
    Doobie.find().fetch()

  test.length stuff, 1

  test.equal stuff[0].foo, "bar"
  test.equal stuff[0]._groupId, serverInstanceId

  next()

Tinytest.addAsync "experiment - instance - addUser records instance id", withCleanup (test, next) ->
  instance = TurkServer.Instance.getInstance(serverInstanceId)
  instance.addUser(expTestUserId)

  user = Meteor.users.findOne(expTestUserId)
  asst = Assignments.findOne(workerId: expTestWorkerId, status: "assigned")

  test.isTrue expTestUserId in instance.users()
  test.equal user.turkserver.state, "experiment"
  test.isTrue(asst.instances instanceof Array)
  test.isTrue(serverInstanceId in asst.instances)

  next()

# TODO clean up assignments if they affect other tests

Tinytest.addAsync "experiment - instance - throws error if doesn't exist", withCleanup (test, next) ->
  test.throws ->
    TurkServer.Instance.getInstance("yabbadabbadoober")
  next()


