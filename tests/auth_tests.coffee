hitId = "authHitId"
hitId2 = "authHitId2"

assignmentId = "authAssignmentId"
assignmentId2 = "authAssignmentId2"

workerId = "authWorkerId"
workerId2 = "authWorkerId2"

experimentId = "authExperimentId"

withCleanup = (fn) ->
  return ->      
    try
      fn.apply(this, arguments)
    catch error
      throw error
    finally
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

  TurkServer.authenticateWorker
    hitId: hitId,
    assignmentId : assignmentId
    workerId: workerId

  record = Assignments.findOne
    hitId: hitId
    assignmentId: assignmentId

  test.isTrue(record)
  test.equal(record.workerId, workerId, "workerId not saved")

Tinytest.add "auth - reconnect - with existing hit after batch retired", withCleanup (test) ->
  batchId = Batches.findOne(active: true)._id
  Batches.update(batchId, $unset: active: false)

  Assignments.insert
    hitId: hitId
    assignmentId: assignmentId

  TurkServer.authenticateWorker
    hitId: hitId,
    assignmentId : assignmentId
    workerId: workerId

  record = Assignments.findOne
    hitId: hitId
    assignmentId: assignmentId

  test.isTrue(record)
  test.equal(record.workerId, workerId, "workerId not saved")
  Batches.update(batchId, $set: active: true)

Tinytest.add "auth - with overlapping hit in experiment", withCleanup (test) ->
  Assignments.insert
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    experimentId: experimentId

  # Authenticate with different worker
  TurkServer.authenticateWorker
    hitId: hitId,
    assignmentId : assignmentId
    workerId: workerId2

  record = Assignments.findOne
    hitId: hitId
    assignmentId: assignmentId

  test.isTrue(record)
  test.equal(record.workerId, workerId2, "workerId not replaced")
  # experimentId erased
  test.isFalse(record.experimentId)

Tinytest.add "auth - with overlapping hit completed", withCleanup (test) ->
  # This case should not happen often
  Assignments.insert
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    experimentId: experimentId
    inactivePercent: 0

  # Authenticate with different worker
  TurkServer.authenticateWorker
    hitId: hitId,
    assignmentId : assignmentId
    workerId: workerId2

  record = Assignments.findOne
    hitId: hitId
    assignmentId: assignmentId

  test.isTrue(record)
  test.equal(record.workerId, workerId2, "workerId not replaced")

  # experimentId and inactivePercent erased
  test.isFalse(record.experimentId)
  test.isFalse(record.inactivePercent)

Tinytest.add "auth - same worker completed hit", withCleanup (test) ->
  Assignments.insert
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    experimentId: experimentId
    inactivePercent: 0

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

  testFunc = -> TurkServer.authenticateWorker
    hitId: hitId2,
    assignmentId : assignmentId2
    workerId: workerId

  test.throws testFunc, (e) ->
    e.error is 403 and e.reason is ErrMsg.simultaneousLimit

Tinytest.add "auth - limit - concurrent across assts", withCleanup (test) ->
  Assignments.insert
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId

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
    experimentId: experimentId
    inactivePercent: 0
    status: "completed"
  # Should not trigger concurrent limit

  testFunc = -> TurkServer.authenticateWorker
    hitId: hitId2,
    assignmentId : assignmentId2
    workerId: workerId

  test.throws testFunc, (e) -> e.error is 403 and e.reason is ErrMsg.batchLimit
  

