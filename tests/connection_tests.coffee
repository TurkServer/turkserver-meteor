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

withCleanup = TestUtils.getCleanupWrapper
  before: ->
    asst = TurkServer.Assignment.createAssignment {
      batchId
      hitId
      assignmentId
      workerId
      acceptTime: Date.now()
      status: "assigned"
    }
  after: ->
    # Remove user from lobby
    batch.lobby.removeUser(asst)
    # Clear user group
    Partitioner.clearUserGroup(userId)
    # Clear any assignments
    Assignments.remove {}
    # Unset user state
    Meteor.users.update userId,
      $unset:
        "turkserver.state": null

Tinytest.add "connection - assignment object preserved in memory", withCleanup (test) ->
  asst2 = TurkServer.Assignment.getAssignment asst.asstId

  test.equal asst2, asst

Tinytest.add "connection - user added to lobby", withCleanup (test) ->
  asst._connected()

  lobbyUsers = batch.lobby.getUsers()
  user = Meteor.users.findOne(userId)

  test.equal lobbyUsers.length, 1
  test.equal lobbyUsers[0]._id, userId

  test.equal user.turkserver.state, "lobby"

Tinytest.add "connection - user resuming into instance", withCleanup (test) ->
  instance.addUser(userId)
  asst._connected()

  user = Meteor.users.findOne(userId)

  test.equal batch.lobby.getUsers().length, 0
  test.equal user.turkserver.state, "experiment"

Tinytest.add "connection - user resuming into exit survey", withCleanup (test) ->
  Meteor.users.update userId,
    $set:
      "turkserver.state": "exitsurvey"

  asst._connected()

  user = Meteor.users.findOne(userId)

  test.equal batch.lobby.getUsers().length, 0
  test.equal user.turkserver.state, "exitsurvey"

