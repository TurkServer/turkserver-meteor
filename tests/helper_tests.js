// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
// TODO: try implementing Meteor.isServer stuff with setUserId

if (Meteor.isClient) {
  Tinytest.addAsync("helpers - isAdmin", (test, next) =>
    InsecureLogin.ready(function() {
      // this should be straight up false - isFalse might take `undefined` for an answer.
      test.equal(TurkServer.isAdmin(), false);
      return next();
    })
  );

  Tinytest.addAsync("helpers - checkAdmin", function(test, next) {
    test.throws(
      () => TurkServer.checkAdmin(),
      e => e.error === 403 && e.reason === ErrMsg.notAdminErr
    );
    return next();
  });

  Tinytest.addAsync("helpers - checkNotAdmin", function(test, next) {
    TurkServer.checkNotAdmin();
    test.ok();
    return next();
  });
}

/*
  Timer helper tests - server/client
*/
Tinytest.add("timers - formatMillis renders 0 properly", test =>
  test.equal(TurkServer.Util.formatMillis(0), "0:00:00")
);

Tinytest.add("timers - formatMillis renders negative values properly", test =>
  test.equal(TurkServer.Util.formatMillis(-1000), "-0:00:01")
);
