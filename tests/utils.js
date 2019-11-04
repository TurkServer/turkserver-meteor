// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
if (Meteor.isClient) {
  // Prevent router from complaining about missing path
  Router.map(function() {
    return this.route("/", {
      onBeforeAction() {
        return this.render(null);
      }
    });
  });
}

if (Meteor.isServer) {
  // Clean up stuff that may have been leftover from other tests
  Meteor.users.remove({});
  Batches.remove({});
  Experiments.remove({});
  Assignments.remove({});
  Treatments.remove({});

  // Stub out the mturk API
  TestUtils.mturkAPI = {
    handler: null
  };

  TurkServer.mturk = function(op, params) {
    TestUtils.mturkAPI.op = op;
    TestUtils.mturkAPI.params = params;
    return typeof TestUtils.mturkAPI.handler === "function"
      ? TestUtils.mturkAPI.handler(op, params)
      : undefined;
  };
}

// Get a wrapper that runs a before and after function wrapping some test function.
TestUtils.getCleanupWrapper = function(settings) {
  // TODO destructuring assignment
  const before = settings.before;
  const after = settings.after;
  // Take a function...
  return (
    fn // Return a function that, when called, executes the hooks around the function.
  ) =>
    function() {
      const next = arguments[1];
      if (typeof before === "function") {
        before();
      }

      if (next == null) {
        // Synchronous version - Tinytest.add
        try {
          return fn.apply(this, arguments);
        } catch (error) {
          throw error;
        } finally {
          if (typeof after === "function") {
            after();
          }
        }
      } else {
        // Asynchronous version - Tinytest.addAsync
        const hookedNext = function() {
          if (typeof after === "function") {
            after();
          }
          return next();
        };
        return fn.call(this, arguments[0], hookedNext);
      }
    };
};

TestUtils.sleep = Meteor.wrapAsync((time, cb) => Meteor.setTimeout(() => cb(undefined), time));

TestUtils.blockingCall = Meteor.wrapAsync(Meteor.call);
