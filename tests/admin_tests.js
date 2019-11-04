// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const batchId = "mturkBatch";
const hitTypeId = "mturkHITType";

// Create dummy batch and HIT Type
Batches.upsert({ _id: batchId }, { _id: batchId });

HITTypes.upsert({HITTypeId: hitTypeId},
  {$set: { batchId }});

// Temporarily disable the admin check during these tests
const _checkAdmin = TurkServer.checkAdmin;

const withCleanup = TestUtils.getCleanupWrapper({
  before() {
    Batches.upsert(batchId, { $set:
      { active: false }
  });
    return TurkServer.checkAdmin = function() {};
  },

  after() {
    HITs.remove({ HITTypeId: hitTypeId });

    // Clean up emails and workers created for testing e-mails
    WorkerEmails.remove({});
    Workers.remove({test: "admin"});

    TestUtils.mturkAPI.handler = null;
    return TurkServer.checkAdmin = _checkAdmin;
  }
});

Tinytest.add("admin - create HIT for active batch", withCleanup(function(test) {

  const newHitId = Random.id();
  TestUtils.mturkAPI.handler = function(op, params) {
    switch (op) {
      case "CreateHIT": return newHitId;
      case "GetHIT": return { CreationTime: new Date }; // Stub out the GetHIT call with some arbitrary data
    }
  };

  Batches.upsert(batchId, {$set: { active: true }});

  // test
  Meteor.call("ts-admin-create-hit", hitTypeId, {});

  const hit = HITs.findOne({HITId: newHitId});

  test.isTrue(hit);
  test.equal(hit.HITId, newHitId);
  return test.equal(hit.HITTypeId, hitTypeId);
})
);

Tinytest.add("admin - create HIT for inactive batch", withCleanup(test => test.throws(() => Meteor.call("ts-admin-create-hit", hitTypeId, {})
, e => e.error === 403))
);

Tinytest.add("admin - extend HIT for active batch", withCleanup(function(test) {

  const HITId = Random.id();
  HITs.insert({ HITId, HITTypeId: hitTypeId });
  Batches.upsert(batchId, {$set: { active: true }});

  // Need to return something for GetHIT else complaining from Mongo et al
  TestUtils.mturkAPI.handler = function(op, params) {
    switch (op) {
      case "GetHIT": return { HITId };
    }
  };

  return Meteor.call("ts-admin-extend-hit", { HITId });}));

Tinytest.add("admin - extend HIT for inactive batch", withCleanup(function(test) {

  const HITId = Random.id();
  HITs.insert({ HITId, HITTypeId: hitTypeId });

  test.throws(() => Meteor.call("ts-admin-extend-hit", { HITId }));
  return e => e.error === 403;
})
);

Tinytest.add("admin - email - create message from existing", withCleanup(function(test) {
  const workers = (__range__(1, 100, true).map((i) => Random.id()));

  const existingId = WorkerEmails.insert({
    subject: "test",
    message: "test message",
    recipients: workers
  });

  const subject = "test2";
  const message = "another test message";

  const newId = Meteor.call("ts-admin-create-message", subject, message, existingId);

  const newEmail = WorkerEmails.findOne(newId);

  test.equal(newEmail.subject, subject);
  test.equal(newEmail.message, message);
  test.length(newEmail.recipients, workers.length);
  test.isTrue(_.isEqual(newEmail.recipients, workers));
  return test.isFalse(newEmail.sentTime);
})
);

Tinytest.add("admin - email - send and record message", withCleanup(function(test) {
  // Create fake workers
  const workerIds = ( __range__(1, 100, true).map((x) => Workers.insert({test: "admin"})) );
  test.equal(workerIds.length, 100);

  const subject = "test sending";
  let message = "test sending message";

  const emailId = WorkerEmails.insert({
    subject,
    message,
    recipients: workerIds
  });

  // Record all the API calls that were made
  let apiWorkers = [];
  TestUtils.mturkAPI.handler = function(op, params) {
    test.equal(params.Subject, subject);
    test.equal(params.MessageText, message);
    return apiWorkers = apiWorkers.concat(params.WorkerId);
  };

  message = Meteor.call("ts-admin-send-message", emailId);
  // First word is the number of messages sent
  // XXX this test may be a little janky
  const count = parseInt(message.split(" ")[0]);

  test.equal(count, workerIds.length);
  test.length(apiWorkers, workerIds.length);
  test.isTrue(_.isEqual(apiWorkers, workerIds));

  // Test that email sending got saved to workers
  let checkedWorkers = 0;
  Workers.find({_id: {$in: workerIds}}).forEach(function(worker) {
    test.equal(worker.emailsReceived[0], emailId);
    return checkedWorkers++;
  });

  test.equal(checkedWorkers, workerIds.length);

  // Test that sent date was recorded
  return test.instanceOf(WorkerEmails.findOne(emailId).sentTime, Date);
})
);

Tinytest.add("admin - assign worker qualification", withCleanup(function(test) {
  const qual = "blahblah";
  const value = 2;
  const workerId = Workers.insert({});

  TestUtils.mturkAPI.handler = function(op, params) {
    test.equal(op, "AssignQualification");
    test.equal(params.QualificationTypeId, qual);
    test.equal(params.WorkerId, workerId);
    test.equal(params.IntegerValue, value);
    return test.equal(params.SendNotification, false);
  };

  TurkServer.Util.assignQualification(workerId, qual, value, false);

  // Check that worker has been updated
  const worker = Workers.findOne(workerId);
  test.equal(worker.quals[0].id, qual);
  return test.equal(worker.quals[0].value, 2);
})
);

Tinytest.add("admin - update worker qualification", withCleanup(function(test) {
  const qual = "blahblah";
  const value = 10;

  const workerId = Workers.insert({
    quals: [ {
      id: qual,
      value: 2
    } ]
  });

  TestUtils.mturkAPI.handler = function(op, params) {
    test.equal(op, "UpdateQualificationScore");
    test.equal(params.QualificationTypeId, qual);
    test.equal(params.SubjectId, workerId);
    return test.equal(params.IntegerValue, value);
  };

  TurkServer.Util.assignQualification(workerId, qual, value, false);

  // Check that worker has been updated
  const worker = Workers.findOne(workerId);

  test.length(worker.quals, 1);
  test.equal(worker.quals[0].id, qual);
  return test.equal(worker.quals[0].value, value);
})
);

function __range__(left, right, inclusive) {
  let range = [];
  let ascending = left < right;
  let end = !inclusive ? right : ascending ? right + 1 : right - 1;
  for (let i = left; ascending ? i < end : i > end; ascending ? i++ : i--) {
    range.push(i);
  }
  return range;
}