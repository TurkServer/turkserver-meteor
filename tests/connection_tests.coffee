batchId = "connectionBatch"

Batches.upsert batchId,
  $set: {}

batch = TurkServer.Batch.getBatch(batchId)

hitId = "connectionHitId"
assignmentId = "connectionAsstId"
workerId = "connectionWorkerId"

userId = "connectionUserId"

Meteor.users.upsert userId, $set: {workerId}

asst = null

instanceId = "connectionInstance"
instance = batch.createInstance()

# Create an assignment. Should only be used at most once per test case.
createAssignment = ->
  TurkServer.Assignment.createAssignment {
    batchId
    hitId
    assignmentId
    workerId
    acceptTime: new Date()
    status: "assigned"
  }

withCleanup = TestUtils.getCleanupWrapper
  before: ->
  after: ->
    # Remove user from lobby
    batch.lobby.removeAssignment(asst)
    # Clear user group
    Partitioner.clearUserGroup(userId)
    # Clear any assignments we created
    Assignments.remove {batchId}
    # Unset user state
    Meteor.users.update userId,
      $unset:
        "turkserver.state": null

Tinytest.add "connection - get existing assignment creates and preserves object", withCleanup (test) ->
  asstId = Assignments.insert {
    batchId
    hitId
    assignmentId
    workerId
    acceptTime: new Date()
    status: "assigned"
  }

  asst = TurkServer.Assignment.getAssignment asstId
  asst2 = TurkServer.Assignment.getAssignment asstId

  test.equal asst2, asst

Tinytest.add "connection - assignment object preserved upon creation", withCleanup (test) ->
  asst = createAssignment()
  asst2 = TurkServer.Assignment.getAssignment asst.asstId

  test.equal asst2, asst

Tinytest.add "connection - user added to lobby", withCleanup (test) ->
  asst = createAssignment()
  TestUtils.connCallbacks.sessionReconnect { userId }

  lobbyUsers = batch.lobby.getAssignments()
  user = Meteor.users.findOne(userId)

  test.equal lobbyUsers.length, 1
  test.equal lobbyUsers[0], asst
  test.equal lobbyUsers[0].userId, userId

  test.equal user.turkserver.state, "lobby"

Tinytest.add "connection - user disconnecting and reconnecting to lobby", withCleanup (test) ->
  asst = createAssignment()

  TestUtils.connCallbacks.sessionReconnect { userId }

  TestUtils.connCallbacks.sessionDisconnect { userId }

  lobbyUsers = batch.lobby.getAssignments()
  user = Meteor.users.findOne(userId)

  test.equal lobbyUsers.length, 0
  test.equal user.turkserver.state, "lobby"

  TestUtils.connCallbacks.sessionReconnect { userId }

  lobbyUsers = batch.lobby.getAssignments()
  user = Meteor.users.findOne(userId)

  test.equal lobbyUsers.length, 1
  test.equal lobbyUsers[0], asst
  test.equal lobbyUsers[0].userId, userId
  test.equal user.turkserver.state, "lobby"

Tinytest.add "connection - user sent to exit survey", withCleanup (test) ->
  asst = createAssignment()
  asst.showExitSurvey()

  user = Meteor.users.findOne(userId)

  test.equal user.turkserver.state, "exitsurvey"

Tinytest.add "connection - user submitting HIT", withCleanup (test) ->
  asst = createAssignment()

  Meteor.users.update userId,
    $set:
      "turkserver.state": "exitsurvey"

  exitData = {foo: "bar"}

  asst.setCompleted( exitData )

  user = Meteor.users.findOne(userId)
  asstData = Assignments.findOne(asst.asstId)

  test.isFalse user.turkserver?.state

  test.isTrue asst.isCompleted()
  test.equal asstData.status, "completed"
  test.instanceOf asstData.submitTime, Date
  test.equal asstData.exitdata, exitData

Tinytest.add "connection - improper submission of HIT", withCleanup (test) ->
  asst = createAssignment()

  test.throws ->
    asst.setCompleted {}
  , (e) -> e.error is 403 and e.reason is ErrMsg.stateErr

Tinytest.add "connection - set assignment as returned", withCleanup (test) ->
  asst = createAssignment()
  TestUtils.connCallbacks.sessionReconnect { userId }

  asst.setReturned()

  user = Meteor.users.findOne(userId)
  asstData = Assignments.findOne(asst.asstId)

  test.equal asstData.status, "returned"
  test.isFalse user.turkserver?.state

Tinytest.add "connection - user resuming into instance", withCleanup (test) ->
  asst = createAssignment()
  instance.addAssignment(asst)
  TestUtils.connCallbacks.sessionReconnect { userId }

  user = Meteor.users.findOne(userId)

  test.equal batch.lobby.getAssignments().length, 0
  test.equal user.turkserver.state, "experiment"

Tinytest.add "connection - user resuming into exit survey", withCleanup (test) ->
  asst = createAssignment()
  Meteor.users.update userId,
    $set:
      "turkserver.state": "exitsurvey"

  TestUtils.connCallbacks.sessionReconnect { userId }

  user = Meteor.users.findOne(userId)

  test.equal batch.lobby.getAssignments().length, 0
  test.equal user.turkserver.state, "exitsurvey"

Tinytest.add "connection - set payment amount", withCleanup (test) ->
  asst = createAssignment()
  test.isFalse asst.getPayment()

  amount = 1.00

  asst.setPayment(amount)
  test.equal asst.getPayment(), amount

  asst.addPayment(1.50)
  test.equal asst.getPayment(), 2.50

Tinytest.add "connection - increment null payment amount", withCleanup (test) ->
  asst = createAssignment()
  test.isFalse asst.getPayment()

  amount = 1.00
  asst.addPayment(amount)
  test.equal asst.getPayment(), amount

Tinytest.add "connection - pay worker bonus", withCleanup (test) ->
  asst = createAssignment()

  test.isFalse(asst._data().bonusPaid)

  amount = 10.00
  asst.setPayment(amount)

  message = "Thanks for your work!"
  asst.payBonus(message)

  test.equal TestUtils.mturkAPI.op, "GrantBonus"
  test.equal TestUtils.mturkAPI.params.WorkerId, asst.workerId
  test.equal TestUtils.mturkAPI.params.AssignmentId, asst.assignmentId
  test.equal TestUtils.mturkAPI.params.BonusAmount.Amount, amount
  test.equal TestUtils.mturkAPI.params.BonusAmount.CurrencyCode, "USD"
  test.equal TestUtils.mturkAPI.params.Reason, message

  asstData = asst._data()
  test.equal asstData.bonusPayment, amount
  test.equal asstData.bonusMessage, message
  test.instanceOf asstData.bonusPaid, Date

Tinytest.add "connection - throw on set/inc payment when bonus paid", withCleanup (test) ->
  asst = createAssignment()

  Assignments.update asst.asstId,
    $set:
      bonusPayment: 0.01
      bonusPaid: new Date
      bonusMessage: "blah"

  amount = 1.00

  test.throws -> asst.setPayment(amount)
  test.equal asst.getPayment(), 0.01

  test.throws -> asst.addPayment(1.50)
  test.equal asst.getPayment(), 0.01

Tinytest.add "connection - throw on double payments", withCleanup (test) ->
  asst = createAssignment()

  amount = 10.00
  asst.setPayment(amount)

  message = "Thanks for your work!"
  asst.payBonus(message)

  test.throws ->
    asst.payBonus(message)
