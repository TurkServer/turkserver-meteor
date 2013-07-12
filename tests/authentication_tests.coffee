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
      res = fn.apply(this, arguments);
    catch error
      throw error
    finally
      Assignments.remove({})
      Meteor.flush()

    return res

Tinytest.add "auth - with unknown hit", withCleanup (test) ->
  TurkServer.authenticateWorker
    hitId: hitId,
    assignmentId : assignmentId
    workerId: workerId

  record = Assignments.findOne
    hitId: hitId
    assignmentId: assignmentId
  test.equal(record.workerId, workerId, "workerId not saved")

Tinytest.add "auth - with existing hit", withCleanup (test) ->
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
  test.equal(record.workerId, workerId, "workerId not saved")

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
  test.equal(record.workerId, workerId2, "workerId not replaced")
  test.isNull(record.experimentId)

Tinytest.add "auth - with overlapping hit completed", withCleanup (test) ->
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
  test.equal(record.workerId, workerId2, "workerId not replaced")
  test.isNull(record.experimentId)
  test.isNull(record.inactivePerecent)

Tinytest.add "auth - same worker completed hit", withCleanup (test) ->
  Assignments.insert
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    experimentId: experimentId
    inactivePercent: 0

  test.throws -> TurkServer.authenticateWorker
    hitId: hitId,
    assignmentId : assignmentId
    workerId: workerId
  , (e) -> e.error is 403 and e.reason is "completed"

Tinytest.add "auth - too many concurrent", withCleanup (test) ->
  Assignments.insert
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId

  test.throws -> TurkServer.authenticateWorker
    hitId: hitId2,
    assignmentId : assignmentId2
    workerId: workerId
  , (e) -> e.error is 403 and e.reason is "too many simultaneous logins"

Tinytest.add "auth - too many total", withCleanup (test) ->
  Assignments.insert
    hitId: hitId
    assignmentId: assignmentId
    workerId: workerId
    experimentId: experimentId
    inactivePercent: 0

  test.throws -> TurkServer.authenticateWorker
    hitId: hitId2,
    assignmentId : assignmentId2
    workerId: workerId
  , (e) -> e.error is 403 and e.reason is "too many hits"
