// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
// Server methods
if (Meteor.isServer) {
  const testGroup = "poop";

  Meteor.methods({
    // Clear anything in logs for the given group
    clearLogs() {
      let group;
      if ((group = Partitioner.group()) == null) {
        throw new Meteor.Error(403, "no group assigned");
      }
      Logs.remove({
        // Should be same as {}, but more explicit
        _groupId: group
      });
    },
    getLogs(selector) {
      let group;
      if ((group = Partitioner.group()) == null) {
        throw new Meteor.Error(403, "no group assigned");
      }
      selector = _.extend(selector || {}, { _groupId: group });
      return Logs.find(selector).fetch();
    }
  });

  Tinytest.add("logging - server group binding", function(test) {
    Partitioner.bindGroup(testGroup, function() {
      Meteor.call("clearLogs");
      return TurkServer.log({
        boo: "hoo"
      });
    });

    const doc = Logs.findOne({ boo: "hoo" });

    test.equal(doc.boo, "hoo");
    test.isTrue(doc._groupId);
    return test.isTrue(doc._timestamp);
  });

  Tinytest.add("logging - override timestamp", function(test) {
    const past = new Date(Date.now() - 1000);

    Partitioner.bindGroup(testGroup, function() {
      Meteor.call("clearLogs");
      return TurkServer.log({
        boo: "hoo",
        _timestamp: past
      });
    });

    const doc = Logs.findOne({ boo: "hoo" });
    test.isTrue(doc._timestamp);
    return test.equal(doc._timestamp, past);
  });
}

// Client methods
// These run after the experiment client tests, so they should be logged in
if (Meteor.isClient) {
  Tinytest.addAsync("logging - initialize test", (test, next) =>
    Meteor.call("clearLogs", function(err, res) {
      test.isFalse(err);
      return next();
    })
  );

  testAsyncMulti("logging - groupId and timestamp", [
    (test, expect) => TurkServer.log({ foo: "bar" }, expect((err, res) => test.isFalse(err))),
    (test, expect) =>
      Meteor.call(
        "getLogs",
        { foo: "bar" },
        expect(function(err, res) {
          test.isFalse(err);
          test.length(res, 1);

          const logItem = res[0];

          test.isTrue(logItem.foo);
          test.isTrue(logItem._userId);
          test.isTrue(logItem._groupId);
          return test.isTrue(logItem._timestamp);
        })
      )
  ]);
}
