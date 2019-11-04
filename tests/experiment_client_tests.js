// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS103: Rewrite code to no longer use __guard__
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
if (Meteor.isServer) {

  // Set up a treatment for testing
  TurkServer.ensureTreatmentExists({
    name: "expWorldTreatment",
    fooProperty: "bar"
  });

  TurkServer.ensureTreatmentExists({
    name: "expUserTreatment",
    foo2: "baz"
  });

  // Some functions to make sure things are set up for the client login
  Accounts.validateLoginAttempt(function(info) {
    if (!info.allowed) { return; } // Don't handle if login is being rejected
    const userId = info.user._id;

    Partitioner.clearUserGroup(userId); // Remove any previous user group
    return true;
  });

  Accounts.onLogin(function(info) {
    const userId = info.user._id;

    // Worker and assignment should have already been created at this point
    const asst = TurkServer.Assignment.getCurrentUserAssignment(userId);

    // Reset assignment for this worker
    Assignments.upsert(asst.asstId, {
      $unset: { instances: null,
      $unset: { treatments: null
    }
    }
    }
    );

    asst.getBatch().createInstance(["expWorldTreatment"]).addAssignment(asst);

    asst.addTreatment("expUserTreatment");

    return Meteor._debug("Remote client logged in");
  });

  Meteor.methods({
    getAssignmentData() {
      const userId = Meteor.userId();
      if (!userId) { throw new Meteor.Error(500, "Not logged in"); }
      const {
        workerId
      } = Meteor.users.findOne(userId);
      return Assignments.findOne({workerId, status: "assigned"});
    },

    setAssignmentPayment(amount) {
      TurkServer.Assignment.currentAssignment().setPayment(amount);
    },

    setAssignmentInstanceData(arr) {
      const selector = {
        workerId: Meteor.user().workerId,
        status: "assigned"
      };

      if (!(Assignments.update(selector, {$set: {instances: arr}}) > 0)) {
        throw new Meteor.Error(400, "Could not find assignment to update");
      }
    },

    endAssignmentInstance(returnToLobby) {
      TurkServer.Instance.currentInstance().teardown(returnToLobby);
    },

    getServerTreatment() {
      return TurkServer.treatment();
    }
  });
}

if (Meteor.isClient) {
  const tol = 20; // range in ms that we can be off in adjacent cols
  const big_tol = 500; // max range we tolerate in a round trip to the server (async method)

  const expectedTreatment = {
    fooProperty: "bar",  // world
    foo2: "baz"         // user
  };

  const checkTreatments = (test, obj) => (() => {
    const result = [];
    for (let k in expectedTreatment) {
      const v = expectedTreatment[k];
      result.push(test.equal(obj[k], v, `for key ${k} actual value ${obj[k]} doesn't match expected value ${v}`));
    }
    return result;
  })();

  Tinytest.addAsync("experiment - client - login and creation of assignment metadata", (test, next) => InsecureLogin.ready(function() {
    test.isTrue(Meteor.userId());
    return next();
  }));

  Tinytest.addAsync("experiment - client - IP address saved", function(test, next) {
    let returned = false;
    Meteor.call("getAssignmentData", function(err, res) {
      returned = true;
      test.isFalse(err);
      console.log("Got assignment data", JSON.stringify(res));

      test.isTrue(__guard__(res != null ? res.ipAddr : undefined, x => x[0]));
      if (Package['test-in-console'] == null) { test.equal(__guard__(res != null ? res.userAgent : undefined, x1 => x1[0]), navigator.userAgent); }

      return next();
    });

    const fail = function() {
      test.fail();
      return next();
    };

    return simplePoll((() => returned), (function() {}), fail, 2000);
  });

  Tinytest.addAsync("experiment - client - received experiment and treatment", function(test, next) {
    let treatment = null;

    const verify = function() {
      console.info("Got treatment ", treatment);

      test.isTrue(Experiments.findOne());
      test.isTrue(treatment);

      // Test world-level treatment
      // No _id or name sent over the wire
      const worldTreatment = TurkServer.treatment("expWorldTreatment");
      test.isFalse(worldTreatment._id);
      test.isTrue(worldTreatment.name);
      test.equal(worldTreatment.fooProperty, "bar");

      // Test user-level treatment
      const userTreatment = TurkServer.treatment("expUserTreatment");
      test.isFalse(userTreatment._id);
      test.isTrue(userTreatment.name);
      test.equal(userTreatment.foo2, "baz");

      checkTreatments(test, TurkServer.treatment());

      return next();
    };

    const fail = function() {
      test.fail();
      return next();
    };

    // Poll until both treatments arrives
    return simplePoll((function() {
      treatment = TurkServer.treatment();
      if (treatment.treatments.length) { return true; }
    }), verify, fail, 2000);
  });

  Tinytest.addAsync("experiment - assignment - test treatments on server", (test, next) => // Even though this is a "client" test, it is testing a server function
  // because assignment treatments are different on the client and server
  Meteor.call("getServerTreatment", function(err, res) {
    if (err != null) { test.fail(); }

    checkTreatments(test, res);
    return next();
  }));

  Tinytest.addAsync("experiment - client - current payment variable", function(test, next) {
    const amount = 0.42;

    return Meteor.call("setAssignmentPayment", amount, function(err, res) {
      test.equal(TurkServer.currentPayment(), amount);
      return next();
    });
  });

  Tinytest.addAsync("experiment - assignment - assignment metadata and local time vars", function(test, next) {
    let asstData = null;

    const verify = function() {
      console.info("Got assignmentData ", asstData);

      test.isTrue(asstData.instances);
      test.isTrue(asstData.instances[0]);

      test.isTrue(TurkServer.Timers.joinedTime() > 0);
      test.equal(TurkServer.Timers.idleTime(), 0);
      test.equal(TurkServer.Timers.disconnectedTime(), 0);

      test.isTrue(Math.abs(TurkServer.Timers.activeTime() - TurkServer.Timers.joinedTime()) < 10);

      return next();
    };

    const fail = function() {
      test.fail();
      return next();
    };

    // Poll until treatment data arrives
    return simplePoll((function() {
      asstData = Assignments.findOne();
      if (asstData != null) { return true; }
    }), verify, fail, 2000);
  });

  Tinytest.addAsync("experiment - assignment - no time fields", function(test, next) {
    const fields = [
      {
        id: TurkServer.group(),
        joinTime: new Date(TimeSync.serverTime())
      }
    ];

    return Meteor.call("setAssignmentInstanceData", fields, function(err, res) {
      test.isFalse(err);
      Deps.flush(); // Help out the emboxed value thingies

      test.equal(TurkServer.Timers.idleTime(), 0);
      test.equal(TurkServer.Timers.disconnectedTime(), 0);

      const joinedTime = TurkServer.Timers.joinedTime();
      const activeTime = TurkServer.Timers.activeTime();

      test.isTrue(joinedTime >= 0);
      test.isTrue(joinedTime < big_tol);

      test.isTrue(activeTime >= 0);

      test.equal(UI._globalHelpers.tsIdleTime(), "0:00:00");
      test.equal(UI._globalHelpers.tsDisconnectedTime(), "0:00:00");

      return next();
    });
  });

  Tinytest.addAsync("experiment - assignment - joined time computation", function(test, next) {
    const fields = [
      {
        id: TurkServer.group(),
        joinTime: new Date(TimeSync.serverTime() - 3000),
        idleTime: 1000,
        disconnectedTime: 2000
      }
    ];

    return Meteor.call("setAssignmentInstanceData", fields, function(err, res) {
      test.isFalse(err);
      Deps.flush(); // Help out the emboxed value thingies

      test.equal(TurkServer.Timers.idleTime(), 1000);
      test.equal(TurkServer.Timers.disconnectedTime(), 2000);

      const joinedTime = TurkServer.Timers.joinedTime();
      const activeTime = TurkServer.Timers.activeTime();

      test.isTrue(joinedTime >= 3000);
      test.isTrue(joinedTime < (3000 + big_tol));
      test.isTrue(Math.abs((activeTime + 3000) - joinedTime) < tol);
      test.isTrue(activeTime >= 0);

      test.equal(UI._globalHelpers.tsIdleTime(), "0:00:01");
      test.equal(UI._globalHelpers.tsDisconnectedTime(), "0:00:02");

      return next();
    });
  });

  Tinytest.addAsync("experiment - instance - instance ended state", function(test, next) {
    // In experiment. not ended
    test.isTrue(TurkServer.inExperiment());
    test.isFalse(TurkServer.instanceEnded());

    return Meteor.call("endAssignmentInstance", false, function(err, res) {
      test.isTrue(TurkServer.inExperiment());
      test.isTrue(TurkServer.instanceEnded());

      return next();
    });
  });

  /*
    Next test edits instance fields, so client APIs may break state
  */

  Tinytest.addAsync(`experiment - instance - client selects correct instance of \
multiple`, function(test, next) {
    const fields = [
      {
        id: Random.id(),
        joinTime: new Date(TimeSync.serverTime() - (3600*1000)),
        idleTime: 3000,
        disconnectedTime: 5000
      },
      {
        id: TurkServer.group(),
        joinTime: new Date(TimeSync.serverTime() - 5000),
        idleTime: 1000,
        disconnectedTime: 2000
      }
    ];

    return Meteor.call("setAssignmentInstanceData", fields, function(err, res) {
      test.isFalse(err);
      Deps.flush(); // Help out the emboxed value thingies

      test.equal(TurkServer.Timers.idleTime(), 1000);
      test.equal(TurkServer.Timers.disconnectedTime(), 2000);

      const joinedTime = TurkServer.Timers.joinedTime();
      const activeTime = TurkServer.Timers.activeTime();

      test.isTrue(joinedTime >= 5000);
      test.isTrue(joinedTime < (5000 + big_tol));

      test.isTrue(Math.abs((activeTime + 3000) - joinedTime) < tol);
      test.isTrue(activeTime >= 0); // Should not be negative

      test.equal(UI._globalHelpers.tsIdleTime(), "0:00:01");
      test.equal(UI._globalHelpers.tsDisconnectedTime(), "0:00:02");

      return next();
    });
  });
}

  // TODO: add a test for submitting HIT and verify that resume token is removed

function __guard__(value, transform) {
  return (typeof value !== 'undefined' && value !== null) ? transform(value) : undefined;
}