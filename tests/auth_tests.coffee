hitId = "authHitId"
hitId2 = "authHitId2"

assignmentId = "authAssignmentId"
assignmentId2 = "authAssignmentId2"

workerId = "authWorkerId"
workerId2 = "authWorkerId2"

experimentId = "authExperimentId"

# Ensure that users with these workerIds exist
Meteor.users.upsert "authUser1", $set: {workerId}
Meteor.users.upsert "authUser2", $set: {workerId: workerId2}

authBatchId = "authBatch"

# Set up a dummy batch
unless Batches.findOne(authBatchId)?
  Batches.insert(_id: authBatchId)

# Set up a dummy HIT type and HIT
unless HITTypes.find().count()
  hitTypeId = HITTypes.insert
    batchId: authBatchId
  hitId = "authHitId"
  HITs.insert
    HITId: hitId
    HitTypeId: hitTypeId

# We can use the after wrapper here because the tests are synchronous
withCleanup = TestUtils.getCleanupWrapper
  before: ->
  after: ->
    Assignments.remove({})
    Meteor.flush()

# TODO add test that requires current batch

Tinytest.add "auth - with unknown hit", withCleanup (test) ->
  TestUtils.authenticateWorker
    batchId: authBatchId
    hitId: hitId
    assignmentId : assignmentId
    workerId: workerId

  record = Assignments.findOne
    hitId: hitId
    assignmentId: assignmentId

  test.isTrue(record)
  test.equal(record.workerId, workerId, "workerId not saved")
  test.equal(record.batchId, authBatchId)

Tinytest.add "auth - reconnect - with existing hit", withCleanup (test) ->
  Assignments.insert
    batchId: authBatchId
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    status: "assigned"

  TestUtils.authenticateWorker
    batchId: authBatchId
    hitId: hitId
    assignmentId : assignmentId
    workerId: workerId

  record = Assignments.findOne
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId

  test.equal(record.status, "assigned")

Tinytest.add "auth - reconnect - with existing hit after batch retired", withCleanup (test) ->
  # TODO clean up batch hack in here
  Batches.update(authBatchId, $unset: active: false)

  Assignments.insert
    batchId: authBatchId
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    status: "assigned"

  TestUtils.authenticateWorker
    batchId: authBatchId
    hitId: hitId
    assignmentId : assignmentId
    workerId: workerId

  record = Assignments.findOne
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId

  test.equal(record.status, "assigned")

  Batches.update(authBatchId, $set: active: true)

Tinytest.add "auth - with overlapping hit in experiment", withCleanup (test) ->
  Assignments.insert
    batchId: authBatchId
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    status: "assigned"
    experimentId: experimentId

  # Authenticate with different worker
  TestUtils.authenticateWorker
    batchId: authBatchId
    hitId: hitId
    assignmentId : assignmentId
    workerId: workerId2

  prevRecord = Assignments.findOne
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId

  newRecord = Assignments.findOne
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId2

  test.equal(prevRecord.status, "returned")

  test.equal(newRecord.status, "assigned")

Tinytest.add "auth - with overlapping hit completed", withCleanup (test) ->
  # This case should not happen often
  Assignments.insert
    batchId: authBatchId
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    status: "completed"

  # Authenticate with different worker
  TestUtils.authenticateWorker
    batchId: authBatchId
    hitId: hitId
    assignmentId : assignmentId
    workerId: workerId2

  prevRecord = Assignments.findOne
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId

  newRecord = Assignments.findOne
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId2

  test.equal(prevRecord.status, "completed")

  test.equal(newRecord.status, "assigned")

Tinytest.add "auth - same worker completed hit", withCleanup (test) ->
  Assignments.insert
    batchId: authBatchId
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    status: "completed"

  testFunc = -> TestUtils.authenticateWorker
    batchId: authBatchId
    hitId: hitId,
    assignmentId : assignmentId
    workerId: workerId

  test.throws testFunc, (e) ->
    e.error is 403 and e.reason is ErrMsg.alreadyCompleted

Tinytest.add "auth - limit - concurrent across hits", withCleanup (test) ->
  Assignments.insert
    batchId: authBatchId
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    status: "assigned"

  testFunc = -> TestUtils.authenticateWorker
    batchId: authBatchId
    hitId: hitId2,
    assignmentId : assignmentId2
    workerId: workerId

  test.throws testFunc, (e) ->
    e.error is 403 and e.reason is ErrMsg.simultaneousLimit

# Not sure this test needs to exist because only 1 assignment per worker for a HIT
Tinytest.add "auth - limit - concurrent across assts", withCleanup (test) ->
  Assignments.insert
    batchId: authBatchId
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    status: "assigned"

  testFunc = -> TestUtils.authenticateWorker
    batchId: authBatchId
    hitId: hitId,
    assignmentId : assignmentId2
    workerId: workerId

  test.throws testFunc, (e) ->
    e.error is 403 and e.reason is ErrMsg.simultaneousLimit

Tinytest.add "auth - limit - too many total", withCleanup (test) ->
  Assignments.insert
    batchId: authBatchId
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    status: "completed"
  # Should not trigger concurrent limit

  testFunc = -> TestUtils.authenticateWorker
    batchId: authBatchId
    hitId: hitId2
    assignmentId : assignmentId2
    workerId: workerId

  test.throws testFunc, (e) -> e.error is 403 and e.reason is ErrMsg.batchLimit

Tinytest.add "auth - limit - allowed after previous batch", withCleanup (test) ->
  Assignments.insert
    batchId: "someOtherBatch"
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    status: "completed"
    # Should not trigger concurrent limit

  TestUtils.authenticateWorker
    batchId: authBatchId
    hitId: hitId2,
    assignmentId : assignmentId2
    workerId: workerId

  prevRecord = Assignments.findOne
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId

  newRecord = Assignments.findOne
    hitId: hitId2
    assignmentId: assignmentId2
    workerId: workerId

  test.equal(prevRecord.status, "completed")
  test.equal(prevRecord.batchId, "someOtherBatch")

  test.equal(newRecord.status, "assigned")
  test.equal(newRecord.batchId, authBatchId)
  

