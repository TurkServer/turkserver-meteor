hitId = "authHitId"
hitId2 = "authHitId2"

assignmentId = "authAssignmentId"
assignmentId2 = "authAssignmentId2"

workerId = "authWorkerId"
workerId2 = "authWorkerId2"

experimentId = "authExperimentId"

# We can use the after wrapper here because the tests are synchronous
withCleanup = TestUtils.getCleanupWrapper
  before: ->
  after: ->
    Assignments.remove({})
    Meteor.flush()

Tinytest.add "auth - with unknown hit", withCleanup (test) ->
  TurkServer.authenticateWorker
    hitId: hitId,
    assignmentId : assignmentId
    workerId: workerId

  record = Assignments.findOne
    hitId: hitId
    assignmentId: assignmentId

  test.isTrue(record)
  test.equal(record.workerId, workerId, "workerId not saved")

Tinytest.add "auth - reconnect - with existing hit", withCleanup (test) ->
  Assignments.insert
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    status: "assigned"

  TurkServer.authenticateWorker
    hitId: hitId,
    assignmentId : assignmentId
    workerId: workerId

  record = Assignments.findOne
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId

  test.equal(record.status, "assigned")

Tinytest.add "auth - reconnect - with existing hit after batch retired", withCleanup (test) ->
  # TODO clean up batch hack in here
  batchId = Batches.findOne(active: true)._id
  Batches.update(batchId, $unset: active: false)

  Assignments.insert
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    status: "assigned"

  TurkServer.authenticateWorker
    hitId: hitId,
    assignmentId : assignmentId
    workerId: workerId

  record = Assignments.findOne
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId

  test.equal(record.status, "assigned")

  Batches.update(batchId, $set: active: true)

Tinytest.add "auth - with overlapping hit in experiment", withCleanup (test) ->
  Assignments.insert
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    status: "assigned"
    experimentId: experimentId

  # Authenticate with different worker
  TurkServer.authenticateWorker
    hitId: hitId,
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
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    status: "completed"

  # Authenticate with different worker
  TurkServer.authenticateWorker
    hitId: hitId,
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
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    status: "completed"

  testFunc = -> TurkServer.authenticateWorker
    hitId: hitId,
    assignmentId : assignmentId
    workerId: workerId

  test.throws testFunc, (e) ->
    e.error is 403 and e.reason is ErrMsg.alreadyCompleted

Tinytest.add "auth - limit - concurrent across hits", withCleanup (test) ->
  Assignments.insert
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    status: "assigned"

  testFunc = -> TurkServer.authenticateWorker
    hitId: hitId2,
    assignmentId : assignmentId2
    workerId: workerId

  test.throws testFunc, (e) ->
    e.error is 403 and e.reason is ErrMsg.simultaneousLimit

# Not sure this test needs to exist because only 1 assignment per worker for a HIT
Tinytest.add "auth - limit - concurrent across assts", withCleanup (test) ->
  Assignments.insert
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    status: "assigned"

  testFunc = -> TurkServer.authenticateWorker
    hitId: hitId,
    assignmentId : assignmentId2
    workerId: workerId

  test.throws testFunc, (e) ->
    e.error is 403 and e.reason is ErrMsg.simultaneousLimit

Tinytest.add "auth - limit - too many total", withCleanup (test) ->
  batchId = Batches.findOne(active: true)._id

  Assignments.insert
    batchId: batchId
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    status: "completed"
  # Should not trigger concurrent limit

  testFunc = -> TurkServer.authenticateWorker
    hitId: hitId2,
    assignmentId : assignmentId2
    workerId: workerId

  test.throws testFunc, (e) -> e.error is 403 and e.reason is ErrMsg.batchLimit

Tinytest.add "auth - limit - allowed after previous batch", withCleanup (test) ->
  batchId = Batches.findOne(active: true)._id

  Assignments.insert
    batchId: "someOtherBatch"
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    status: "completed"
    # Should not trigger concurrent limit

  TurkServer.authenticateWorker
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
  test.equal(newRecord.batchId, batchId)
  

