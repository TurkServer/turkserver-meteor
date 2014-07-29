hitType = "authHitType"

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
otherBatchId = "someOtherBatch"

# Set up a dummy batch
unless Batches.findOne(authBatchId)?
  Batches.insert(_id: authBatchId)

# Set up a dummy HIT type and HITs
HITTypes.upsert HITTypeId: hitType,
  $set:
    batchId: authBatchId
HITs.upsert HITId: hitId,
  $set: HITTypeId: hitType
HITs.upsert HITId: hitId2,
  $set: HITTypeId: hitType

# We can use the after wrapper here because the tests are synchronous
withCleanup = TestUtils.getCleanupWrapper
  before: ->
    Batches.update authBatchId,
      $set: active: true
      $unset: acceptReturns: null
  after: ->
    # Only remove assignments created here to avoid side effects on server-client tests
    Assignments.remove($or: [ {batchId: authBatchId}, {batchId: otherBatchId} ])

Tinytest.add "auth - with first time hit assignment", withCleanup (test) ->
  asst = TestUtils.authenticateWorker
    batchId: authBatchId
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId

  # Test in-memory stored values
  test.equal asst.batchId, authBatchId
  test.equal asst.hitId, hitId
  test.equal asst.assignmentId, assignmentId
  test.equal asst.workerId, workerId
  test.equal asst.userId, "authUser1"

  # Test database storage
  record = Assignments.findOne
    hitId: hitId
    assignmentId: assignmentId

  test.isTrue(record)
  test.equal(record.workerId, workerId, "workerId not saved")
  test.equal(record.batchId, authBatchId)

Tinytest.add "auth - reject incorrect batch", withCleanup (test) ->
  testFunc = -> TestUtils.authenticateWorker
    batchId: otherBatchId
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId

  test.throws testFunc, (e) ->
    e.error is 403 and e.reason is ErrMsg.unexpectedBatch

Tinytest.add "auth - connection to inactive batch is rejected", withCleanup (test) ->
  # Active is set to back to true on cleanup
  Batches.update(authBatchId, $unset: active: false)

  testFunc = -> TestUtils.authenticateWorker
    batchId: authBatchId
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId

  test.throws testFunc, (e) ->
    e.error is 403 and e.reason is ErrMsg.batchInactive

Tinytest.add "auth - reconnect - with existing hit assignment", withCleanup (test) ->
  Assignments.insert
    batchId: authBatchId
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    status: "assigned"

  # This needs to return an assignment
  asst = TestUtils.authenticateWorker
    batchId: authBatchId
    hitId: hitId
    assignmentId : assignmentId
    workerId: workerId

  record = Assignments.findOne
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId

  test.equal(asst, TurkServer.Assignment.getAssignment(record._id))
  test.equal asst.batchId, authBatchId
  test.equal asst.hitId, hitId
  test.equal asst.assignmentId, assignmentId
  test.equal asst.workerId, workerId
  test.equal asst.userId, "authUser1"

  test.equal(record.status, "assigned")

Tinytest.add "auth - reconnect - with existing hit after batch is inactive", withCleanup (test) ->
  # Active is set to back to true on cleanup
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

Tinytest.add "auth - with overlapping hit in experiment", withCleanup (test) ->
  Assignments.insert
    batchId: authBatchId
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    status: "assigned"
    experimentId: experimentId

  # Authenticate with different worker
  asst = TestUtils.authenticateWorker
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

  test.isTrue(asst)
  test.equal(asst, TurkServer.Assignment.getAssignment(newRecord._id))

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
  asst = TestUtils.authenticateWorker
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

  test.isTrue(asst)
  test.equal(asst, TurkServer.Assignment.getAssignment(newRecord._id))

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

Tinytest.add "auth - limit - returns not allowed in batch", withCleanup (test) ->
  Assignments.insert
    batchId: authBatchId
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    status: "returned"
  # Should not trigger concurrent limit

  testFunc = -> TestUtils.authenticateWorker
    batchId: authBatchId
    hitId: hitId2
    assignmentId : assignmentId2
    workerId: workerId

  test.throws testFunc, (e) -> e.error is 403 and e.reason is ErrMsg.batchLimit

Tinytest.add "auth - limit - returns allowed in batch", withCleanup (test) ->
  Batches.update(authBatchId, $set: acceptReturns: true)

  Assignments.insert
    batchId: authBatchId
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    status: "returned"

  asst = TestUtils.authenticateWorker
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

  test.isTrue(asst)
  test.equal(asst, TurkServer.Assignment.getAssignment(newRecord._id))

  test.equal(prevRecord.status, "returned")
  test.equal(prevRecord.batchId, authBatchId)

  test.equal(newRecord.status, "assigned")
  test.equal(newRecord.batchId, authBatchId)

Tinytest.add "auth - limit - allowed after previous batch", withCleanup (test) ->
  Assignments.insert
    batchId: otherBatchId
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    status: "completed"
    # Should not trigger concurrent limit

  asst = TestUtils.authenticateWorker
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

  test.isTrue(asst)
  test.equal(asst, TurkServer.Assignment.getAssignment(newRecord._id))

  test.equal(prevRecord.status, "completed")
  test.equal(prevRecord.batchId, "someOtherBatch")

  test.equal(newRecord.status, "assigned")
  test.equal(newRecord.batchId, authBatchId)

# Worker is used for the test below
Meteor.users.upsert "testWorker", $set: {workerId: "testingWorker"}

Tinytest.add "auth - testing HIT login doesn't require existing HIT", withCleanup (test) ->
  asst = TestUtils.authenticateWorker
    batchId: authBatchId
    hitId: "testingHIT"
    assignmentId: "testingAsst"
    workerId: "testingWorker"
    test: true

  # Test database storage
  record = Assignments.findOne
    hitId: "testingHIT"
    assignmentId: "testingAsst"

  test.isTrue(asst)
  test.equal(asst, TurkServer.Assignment.getAssignment(record._id))

  test.isTrue(record)
  test.equal(record.workerId, "testingWorker")
  test.equal(record.batchId, authBatchId)
