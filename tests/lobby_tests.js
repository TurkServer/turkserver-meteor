if Meteor.isServer
  # Create a batch to test the lobby on
  batchId = "lobbyBatchTest"
  Batches.upsert { _id: batchId }, { _id: batchId }

  lobby = TurkServer.Batch.getBatch(batchId).lobby

  userId = "lobbyUser"

  Meteor.users.upsert userId,
    $set: {
      workerId: "lobbyTestWorker"
    }

  Assignments.upsert {
    batchId
    hitId: "lobbyTestHIT"
    assignmentId: "lobbyTestAsst"
  }, $set:
    workerId: "lobbyTestWorker"
    status: "assigned"

  asst = TurkServer.Assignment.getCurrentUserAssignment(userId)

  joinedUserId = null
  changedUserId = null
  leftUserId = null

  lobby.events.on "user-join", (asst) -> joinedUserId = asst.userId
  lobby.events.on "user-status", (asst) -> changedUserId = asst.userId
  lobby.events.on "user-leave", (asst) -> leftUserId = asst.userId

  withCleanup = TestUtils.getCleanupWrapper
    before: ->
      lobby.pluckUsers [userId]
      joinedUserId = null
      changedUserId = null
      leftUserId = null
    after: ->

  # Basic tests just to make sure joining/leaving works as intended
  Tinytest.addAsync "lobby - add user", withCleanup (test, next) ->
    lobby.addAssignment(asst)

    Meteor.defer ->
      test.equal joinedUserId, userId

      lobbyAssts = lobby.getAssignments()
      test.length lobbyAssts, 1
      test.equal lobbyAssts[0], asst
      test.equal lobbyAssts[0].userId, userId

      lobbyData = LobbyStatus.findOne(userId)
      test.equal lobbyData.batchId, batchId
      test.equal lobbyData.asstId, asst.asstId

      next()

  # TODO update this test for generalized lobby user state
  Tinytest.addAsync "lobby - change state", withCleanup (test, next) ->
    lobby.addAssignment(asst)
    lobby.toggleStatus(asst.userId)

    lobbyUsers = lobby.getAssignments()
    test.length lobbyUsers, 1
    test.equal lobbyUsers[0], asst
    test.equal lobbyUsers[0].userId, userId

    # TODO: use better API for accessing user status
    test.equal LobbyStatus.findOne(asst.userId)?.status, true

    Meteor.defer ->
      test.equal changedUserId, userId
      next()

  Tinytest.addAsync "lobby - remove user", withCleanup (test, next) ->
    lobby.addAssignment(asst)
    lobby.removeAssignment(asst)

    lobbyUsers = lobby.getAssignments()
    test.length lobbyUsers, 0

    Meteor.defer ->
      test.equal leftUserId, userId
      next()

  Tinytest.addAsync "lobby - remove nonexistent user", withCleanup (test, next) ->
    # TODO create an assignment with some other state here
    lobby.removeAssignment("rando")

    Meteor.defer ->
      test.equal leftUserId, null
      next()

if Meteor.isClient
  # TODO fix config test for lobby along with assigner lobby state
  undefined
#  Tinytest.addAsync "lobby - verify config", (test, next) ->
#    groupSize = null
#
#    verify = ->
#      test.isTrue groupSize
#      test.equal groupSize.value, 3
#      next()
#
#    fail = ->
#      test.fail()
#      next()
#
#    simplePoll (-> (groupSize = TSConfig.findOne("lobbyThreshold"))? ), verify, fail, 2000
