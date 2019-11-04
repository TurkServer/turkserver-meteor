// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS202: Simplify dynamic range loops
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const testGroup = "timerTest";

// use a before here because tests are async
const withCleanup = TestUtils.getCleanupWrapper({
  before() {
    // Clear any timer information
    Partitioner.bindGroup(testGroup, () => RoundTimers.remove({}));
    // Clear any handlers
    return TestUtils.clearRoundHandlers();
  }
});

Tinytest.addAsync(
  "timers - expiration callback",
  withCleanup((test, next) =>
    Partitioner.bindGroup(testGroup, function() {
      const now = new Date();

      TurkServer.Timers.onRoundEnd(function(type) {
        test.equal(type, TurkServer.Timers.ROUND_END_TIMEOUT);
        // Cancel group binding
        return Partitioner._currentGroup.withValue(null, next);
      });

      return TurkServer.Timers.startNewRound(now, new Date(now.getTime() + 100));
    })
  )
);

Tinytest.addAsync(
  "timers - start multiple rounds",
  withCleanup((test, next) =>
    Partitioner.bindGroup(testGroup, function() {
      const now = new Date();

      TurkServer.Timers.onRoundEnd(function(type) {
        test.equal(type, TurkServer.Timers.ROUND_END_NEWROUND);

        return Partitioner._currentGroup.withValue(null, next);
      });

      TurkServer.Timers.startNewRound(now, new Date(now.getTime() + 100));
      return TurkServer.Timers.startNewRound(now, new Date(now.getTime() + 100));
    })
  )
);

Tinytest.addAsync(
  "timers - end and start new rounds",
  withCleanup((test, next) =>
    Partitioner.bindGroup(testGroup, function() {
      TurkServer.Timers.onRoundEnd(type => test.equal(type, TurkServer.Timers.ROUND_END_MANUAL));

      const nRounds = 10;

      for (let i = 1, end = nRounds, asc = 1 <= end; asc ? i <= end : i >= end; asc ? i++ : i--) {
        const now = new Date();
        TurkServer.Timers.startNewRound(now, new Date(now.getTime() + 100));
        TurkServer.Timers.endCurrentRound();
      }

      // Make sure there are the right number of rounds
      test.length(RoundTimers.find().fetch(), nRounds);

      return Partitioner._currentGroup.withValue(null, next);
    })
  )
);

Tinytest.addAsync(
  "timers - early expiration",
  withCleanup((test, next) =>
    Partitioner.bindGroup(testGroup, function() {
      const now = new Date();

      let count = 0;
      const types = {};

      TurkServer.Timers.onRoundEnd(function(type) {
        count++;
        if (types[type] == null) {
          types[type] = 0;
        }
        return types[type]++;
      });

      TurkServer.Timers.startNewRound(now, new Date(now.getTime() + 100));

      TurkServer.Timers.endCurrentRound();

      // round end callback should only have been called once
      return Meteor.setTimeout(function() {
        test.equal(count, 1);
        test.equal(types[TurkServer.Timers.ROUND_END_MANUAL], 1);
        // Cancel group binding
        return Partitioner._currentGroup.withValue(null, next);
      }, 150);
    })
  )
);

Tinytest.addAsync(
  "timers - robustness to multiple calls",
  withCleanup((test, next) =>
    Partitioner.bindGroup(testGroup, function() {
      const now = new Date();
      const end = new Date(now.getTime() + 300);

      let errors = 0;

      const testFunc = function() {
        try {
          return TurkServer.Timers.startNewRound(now, end);
        } catch (e) {
          // We should get at least one error here.
          console.log(e);
          return errors++;
        }
      };

      // Make sure that running a bunch of these simultaneously doesn't bug out
      for (let _ = 1; _ <= 10; _++) {
        Meteor.defer(testFunc);
      }

      return Meteor.setTimeout(function() {
        // TODO: do something smarter with RoundTimers.find().fetch()
        test.isTrue(errors > 0);
        test.isTrue(errors < 10);

        return next();
      }, 500);
    })
  )
);

Tinytest.addAsync(
  "timers - reschedule on server restart",
  withCleanup((test, next) =>
    Partitioner.bindGroup(testGroup, function() {
      const now = new Date();

      TurkServer.Timers.onRoundEnd(function() {
        test.ok();
        // Cancel group binding
        return Partitioner._currentGroup.withValue(null, next);
      });

      TurkServer.Timers.startNewRound(now, new Date(now.getTime() + 100));

      // Prevent the normal timeout from being called
      Meteor.clearTimeout(TestUtils.lastScheduledRound);

      // Pretend the server restarted
      return TestUtils.scheduleOutstandingRounds();
    })
  )
);
