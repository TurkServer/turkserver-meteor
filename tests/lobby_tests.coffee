if Meteor.isServer
  # Create a batch to test the lobby on
  batchId = "lobbyBatchTest"
  Batches.upsert batchId, $set: {}

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
    after: -> # Can't use this for async

  # Basic tests just to make sure joining/leaving works as intended
  Tinytest.addAsync "lobby - add user", withCleanup (test, next) ->
    lobby.addUser(asst)

    Meteor.defer ->
      test.equal joinedUserId, userId
      next()

  Tinytest.addAsync "lobby - change state", withCleanup (test, next) ->
    lobby.addUser(asst)
    lobby.toggleStatus(asst)

    lobbyUsers = lobby.getUsers()
    test.length lobbyUsers, 1
    test.equal lobbyUsers[0]._id, userId
    test.equal lobbyUsers[0].status, true

    Meteor.defer ->
      test.equal changedUserId, userId
      next()

  Tinytest.addAsync "lobby - remove user", withCleanup (test, next) ->
    lobby.addUser(asst)
    lobby.removeUser(asst)

    lobbyUsers = lobby.getUsers()
    test.length lobbyUsers, 0

    Meteor.defer ->
      test.equal leftUserId, userId
      next()

  Tinytest.addAsync "lobby - remove nonexistent user", withCleanup (test, next) ->
    lobby.removeUser("rando")

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
