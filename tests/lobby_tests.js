// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS103: Rewrite code to no longer use __guard__
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
if (Meteor.isServer) {
  // Create a batch to test the lobby on
  const batchId = "lobbyBatchTest";
  Batches.upsert({ _id: batchId }, { _id: batchId });

  const lobby = TurkServer.Batch.getBatch(batchId).lobby;

  const userId = "lobbyUser";

  Meteor.users.upsert(userId, {
    $set: {
      workerId: "lobbyTestWorker"
    }
  });

  Assignments.upsert(
    {
      batchId,
      hitId: "lobbyTestHIT",
      assignmentId: "lobbyTestAsst"
    },
    {
      $set: {
        workerId: "lobbyTestWorker",
        status: "assigned"
      }
    }
  );

  const asst = TurkServer.Assignment.getCurrentUserAssignment(userId);

  let joinedUserId = null;
  let changedUserId = null;
  let leftUserId = null;

  lobby.events.on("user-join", asst => (joinedUserId = asst.userId));
  lobby.events.on("user-status", asst => (changedUserId = asst.userId));
  lobby.events.on("user-leave", asst => (leftUserId = asst.userId));

  const withCleanup = TestUtils.getCleanupWrapper({
    before() {
      lobby.pluckUsers([userId]);
      joinedUserId = null;
      changedUserId = null;
      return (leftUserId = null);
    },
    after() {}
  });

  // Basic tests just to make sure joining/leaving works as intended
  Tinytest.addAsync(
    "lobby - add user",
    withCleanup(function(test, next) {
      lobby.addAssignment(asst);

      return Meteor.defer(function() {
        test.equal(joinedUserId, userId);

        const lobbyAssts = lobby.getAssignments();
        test.length(lobbyAssts, 1);
        test.equal(lobbyAssts[0], asst);
        test.equal(lobbyAssts[0].userId, userId);

        const lobbyData = LobbyStatus.findOne(userId);
        test.equal(lobbyData.batchId, batchId);
        test.equal(lobbyData.asstId, asst.asstId);

        return next();
      });
    })
  );

  // TODO update this test for generalized lobby user state
  Tinytest.addAsync(
    "lobby - change state",
    withCleanup(function(test, next) {
      lobby.addAssignment(asst);
      lobby.toggleStatus(asst.userId);

      const lobbyUsers = lobby.getAssignments();
      test.length(lobbyUsers, 1);
      test.equal(lobbyUsers[0], asst);
      test.equal(lobbyUsers[0].userId, userId);

      // TODO: use better API for accessing user status
      test.equal(__guard__(LobbyStatus.findOne(asst.userId), x => x.status), true);

      return Meteor.defer(function() {
        test.equal(changedUserId, userId);
        return next();
      });
    })
  );

  Tinytest.addAsync(
    "lobby - remove user",
    withCleanup(function(test, next) {
      lobby.addAssignment(asst);
      lobby.removeAssignment(asst);

      const lobbyUsers = lobby.getAssignments();
      test.length(lobbyUsers, 0);

      return Meteor.defer(function() {
        test.equal(leftUserId, userId);
        return next();
      });
    })
  );

  Tinytest.addAsync(
    "lobby - remove nonexistent user",
    withCleanup(function(test, next) {
      // TODO create an assignment with some other state here
      lobby.removeAssignment("rando");

      return Meteor.defer(function() {
        test.equal(leftUserId, null);
        return next();
      });
    })
  );
}

if (Meteor.isClient) {
  // TODO fix config test for lobby along with assigner lobby state
  undefined;
}
//  Tinytest.addAsync "lobby - verify config", (test, next) ->
//    groupSize = null
//
//    verify = ->
//      test.isTrue groupSize
//      test.equal groupSize.value, 3
//      next()
//
//    fail = ->
//      test.fail()
//      next()
//
//    simplePoll (-> (groupSize = TSConfig.findOne("lobbyThreshold"))? ), verify, fail, 2000

function __guard__(value, transform) {
  return typeof value !== "undefined" && value !== null ? transform(value) : undefined;
}
