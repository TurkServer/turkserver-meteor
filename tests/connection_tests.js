/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const batchId = "connectionBatch";

Batches.upsert({ _id: batchId }, { _id: batchId });

const batch = TurkServer.Batch.getBatch(batchId);

const hitId = "connectionHitId";
const assignmentId = "connectionAsstId";
const workerId = "connectionWorkerId";

const userId = "connectionUserId";

Meteor.users.upsert(userId, {$set: {workerId}});

let asst = null;

const instanceId = "connectionInstance";
const instance = batch.createInstance();

// Create an assignment. Should only be used at most once per test case.
const createAssignment = () => TurkServer.Assignment.createAssignment({
  batchId,
  hitId,
  assignmentId,
  workerId,
  acceptTime: new Date(),
  status: "assigned"
});

const withCleanup = TestUtils.getCleanupWrapper({
  before() {},
  after() {
    // Remove user from lobby
    batch.lobby.removeAssignment(asst);
    // Clear user group
    Partitioner.clearUserGroup(userId);
    // Clear any assignments we created
    Assignments.remove({batchId});
    // Unset user state
    return Meteor.users.update(userId, {
      $unset: {
        "turkserver.state": null
      }
    }
    );
  }
});

Tinytest.add("connection - get existing assignment creates and preserves object", withCleanup(function(test) {
  const asstId = Assignments.insert({
    batchId,
    hitId,
    assignmentId,
    workerId,
    acceptTime: new Date(),
    status: "assigned"
  });

  asst = TurkServer.Assignment.getAssignment(asstId);
  const asst2 = TurkServer.Assignment.getAssignment(asstId);

  return test.equal(asst2, asst);
})
);

Tinytest.add("connection - assignment object preserved upon creation", withCleanup(function(test) {
  asst = createAssignment();
  const asst2 = TurkServer.Assignment.getAssignment(asst.asstId);

  return test.equal(asst2, asst);
})
);

Tinytest.add("connection - get active user assignment", withCleanup(function(test) {
  asst = createAssignment();
  const asst2 = TurkServer.Assignment.getCurrentUserAssignment(asst.userId);

  return test.equal(asst2, asst);
})
);

Tinytest.add("connection - assignment removed from cache after return", withCleanup(function(test) {
  asst = createAssignment();
  asst.setReturned();

  // Let cache cleanup do its thing
  TestUtils.sleep(200);

  return test.isUndefined(TurkServer.Assignment.getCurrentUserAssignment(asst.userId));
})
);

Tinytest.add("connection - assignment removed from cache after completion", withCleanup(function(test) {
  asst = createAssignment();
  asst.showExitSurvey();
  asst.setCompleted({});

  // Let cache cleanup do its thing
  TestUtils.sleep(200);

  return test.isUndefined(TurkServer.Assignment.getCurrentUserAssignment(asst.userId));
})
);

Tinytest.add("connection - user added to lobby", withCleanup(function(test) {
  asst = createAssignment();
  TestUtils.connCallbacks.sessionReconnect({ userId });

  const lobbyUsers = batch.lobby.getAssignments();
  const user = Meteor.users.findOne(userId);

  test.equal(lobbyUsers.length, 1);
  test.equal(lobbyUsers[0], asst);
  test.equal(lobbyUsers[0].userId, userId);

  return test.equal(user.turkserver.state, "lobby");
})
);

Tinytest.add("connection - user disconnecting and reconnecting to lobby", withCleanup(function(test) {
  asst = createAssignment();

  TestUtils.connCallbacks.sessionReconnect({ userId });

  TestUtils.connCallbacks.sessionDisconnect({ userId });

  let lobbyUsers = batch.lobby.getAssignments();
  let user = Meteor.users.findOne(userId);

  test.equal(lobbyUsers.length, 0);
  test.equal(user.turkserver.state, "lobby");

  TestUtils.connCallbacks.sessionReconnect({ userId });

  lobbyUsers = batch.lobby.getAssignments();
  user = Meteor.users.findOne(userId);

  test.equal(lobbyUsers.length, 1);
  test.equal(lobbyUsers[0], asst);
  test.equal(lobbyUsers[0].userId, userId);
  return test.equal(user.turkserver.state, "lobby");
})
);

Tinytest.add("connection - user sent to exit survey", withCleanup(function(test) {
  asst = createAssignment();
  asst.showExitSurvey();

  const user = Meteor.users.findOne(userId);

  return test.equal(user.turkserver.state, "exitsurvey");
})
);

Tinytest.add("connection - user submitting HIT", withCleanup(function(test) {
  asst = createAssignment();

  Meteor.users.update(userId, {
    $set: {
      "turkserver.state": "exitsurvey"
    }
  }
  );

  const exitData = {foo: "bar"};

  asst.setCompleted( exitData );

  const user = Meteor.users.findOne(userId);
  const asstData = Assignments.findOne(asst.asstId);

  test.isFalse(user.turkserver != null ? user.turkserver.state : undefined);

  test.isTrue(asst.isCompleted());
  test.equal(asstData.status, "completed");
  test.instanceOf(asstData.submitTime, Date);
  return test.equal(asstData.exitdata, exitData);
})
);

Tinytest.add("connection - improper submission of HIT", withCleanup(function(test) {
  asst = createAssignment();

  return test.throws(() => asst.setCompleted({})
  , e => (e.error === 403) && (e.reason === ErrMsg.stateErr));
})
);

Tinytest.add("connection - set assignment as returned", withCleanup(function(test) {
  asst = createAssignment();
  TestUtils.connCallbacks.sessionReconnect({ userId });

  asst.setReturned();

  const user = Meteor.users.findOne(userId);
  const asstData = Assignments.findOne(asst.asstId);

  test.equal(asstData.status, "returned");
  return test.isFalse(user.turkserver != null ? user.turkserver.state : undefined);
})
);

Tinytest.add("connection - user resuming into instance", withCleanup(function(test) {
  asst = createAssignment();
  instance.addAssignment(asst);
  TestUtils.connCallbacks.sessionReconnect({ userId });

  const user = Meteor.users.findOne(userId);

  test.equal(batch.lobby.getAssignments().length, 0);
  return test.equal(user.turkserver.state, "experiment");
})
);

Tinytest.add("connection - user resuming into exit survey", withCleanup(function(test) {
  asst = createAssignment();
  Meteor.users.update(userId, {
    $set: {
      "turkserver.state": "exitsurvey"
    }
  }
  );

  TestUtils.connCallbacks.sessionReconnect({ userId });

  const user = Meteor.users.findOne(userId);

  test.equal(batch.lobby.getAssignments().length, 0);
  return test.equal(user.turkserver.state, "exitsurvey");
})
);

Tinytest.add("connection - set payment amount", withCleanup(function(test) {
  asst = createAssignment();
  test.isFalse(asst.getPayment());

  const amount = 1.00;

  asst.setPayment(amount);
  test.equal(asst.getPayment(), amount);

  asst.addPayment(1.50);
  return test.equal(asst.getPayment(), 2.50);
})
);

Tinytest.add("connection - increment null payment amount", withCleanup(function(test) {
  asst = createAssignment();
  test.isFalse(asst.getPayment());

  const amount = 1.00;
  asst.addPayment(amount);
  return test.equal(asst.getPayment(), amount);
})
);

Tinytest.add("connection - pay worker bonus", withCleanup(function(test) {
  asst = createAssignment();

  test.isFalse(asst._data().bonusPaid);

  const amount = 10.00;
  asst.setPayment(amount);

  const message = "Thanks for your work!";
  asst.payBonus(message);

  test.equal(TestUtils.mturkAPI.op, "GrantBonus");
  test.equal(TestUtils.mturkAPI.params.WorkerId, asst.workerId);
  test.equal(TestUtils.mturkAPI.params.AssignmentId, asst.assignmentId);
  test.equal(TestUtils.mturkAPI.params.BonusAmount.Amount, amount);
  test.equal(TestUtils.mturkAPI.params.BonusAmount.CurrencyCode, "USD");
  test.equal(TestUtils.mturkAPI.params.Reason, message);

  const asstData = asst._data();
  test.equal(asstData.bonusPayment, amount);
  test.equal(asstData.bonusMessage, message);
  return test.instanceOf(asstData.bonusPaid, Date);
})
);

Tinytest.add("connection - throw on set/inc payment when bonus paid", withCleanup(function(test) {
  asst = createAssignment();

  Assignments.update(asst.asstId, {
    $set: {
      bonusPayment: 0.01,
      bonusPaid: new Date,
      bonusMessage: "blah"
    }
  }
  );

  const amount = 1.00;

  test.throws(() => asst.setPayment(amount));
  test.equal(asst.getPayment(), 0.01);

  test.throws(() => asst.addPayment(1.50));
  return test.equal(asst.getPayment(), 0.01);
})
);

Tinytest.add("connection - throw on double payments", withCleanup(function(test) {
  asst = createAssignment();

  const amount = 10.00;
  asst.setPayment(amount);

  const message = "Thanks for your work!";
  asst.payBonus(message);

  return test.throws(() => asst.payBonus(message));
})
);
