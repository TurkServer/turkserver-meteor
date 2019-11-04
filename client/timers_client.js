// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS103: Rewrite code to no longer use __guard__
 * DS203: Remove `|| {}` from converted for-own loops
 * DS206: Consider reworking classes to avoid initClass
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
/*
  Reactive time functions

  The instance time functions are also used in the admin interface to compute
  individual users' stats.
*/
(function() {
  let _currentAssignmentInstance = undefined;
  let _joinedTime = undefined;
  let _idleTime = undefined;
  let _disconnectedTime = undefined;
  const Cls = (TurkServer.Timers = class Timers {
    static initClass() {
      _currentAssignmentInstance = function() {
        let group;
        if (TurkServer.isAdmin()) { return; }
        if ((group = TurkServer.group()) == null) { return; }
        return _.find(__guard__(Assignments.findOne(), x => x.instances), inst => inst.id === group);
      };
  
      _joinedTime = (instance, serverTime) => Math.max(0, serverTime - instance.joinTime);
  
      _idleTime = function(instance, serverTime) {
        let idleMillis = (instance.idleTime || 0);
        // If we're idle, add the time since we went idle
        // TODO add a test for this part
        if (instance.lastIdle != null) {
          idleMillis += serverTime - instance.lastIdle;
        }
        return idleMillis;
      };
  
      _disconnectedTime = function(instance, serverTime) {
        let discMillis = instance.disconnectedTime || 0;
        if (instance.lastDisconnect != null) {
          discMillis += serverTime - instance.lastDisconnect;
        }
        return discMillis;
      };
    }

    // Milliseconds elapsed since experiment start
    static elapsedTime() {
      let exp;
      if ((exp = Experiments.findOne()) == null) { return; }
      if (exp.startTime == null) { return; }
      return Math.max(0, TimeSync.serverTime() - exp.startTime);
    }

    // TODO: clean up code repetition below

    // Milliseconds elapsed since this user joined the experiment instance
    // This is slightly different than the above
    static joinedTime(instance) {
      if ((instance != null ? instance : (instance = _currentAssignmentInstance())) == null) { return; }
      const serverTime = instance.leaveTime || TimeSync.serverTime();
      return _joinedTime(instance, serverTime);
    }

    static remainingTime() {
      let exp;
      if ((exp = Experiments.findOne()) == null) { return; }
      if (exp.endTime == null) { return; }
      return Math.max(0, exp.endTime - TimeSync.serverTime());
    }

    /*
      Emboxed values below because they aren't using per-second reactivity
    */

    // Milliseconds this user has been idle in the experiment
    static idleTime(instance) {
      if ((instance != null ? instance : (instance = _currentAssignmentInstance())) == null) { return; }
      const serverTime = instance.leaveTime || TimeSync.serverTime();
      return _idleTime(instance, serverTime);
    }

    // Milliseconds this user has been disconnected in the experiment
    static disconnectedTime(instance) {
      if ((instance != null ? instance : (instance = _currentAssignmentInstance())) == null) { return; }
      const serverTime = instance.leaveTime || TimeSync.serverTime();
      return _disconnectedTime(instance, serverTime);
    }

    static activeTime(instance) {
      if ((instance != null ? instance : (instance = _currentAssignmentInstance())) == null) { return; }
      // Compute this using helper functions to avoid thrashing
      const serverTime = instance.leaveTime || TimeSync.serverTime();
      return _joinedTime(instance, serverTime) - _idleTime(instance, serverTime) - _disconnectedTime(instance, serverTime);
    }

    // Milliseconds elapsed since round start
    static roundElapsedTime() {
      let round;
      if ((round = TurkServer.currentRound()) == null) { return; }
      if (round.startTime == null) { return; }
      return Math.max(0, TimeSync.serverTime() - round.startTime);
    }

    // Milliseconds until end of round
    static roundRemainingTime() {
      let round;
      if ((round = TurkServer.currentRound()) == null) { return; }
      if (round.endTime == null) { return; }
      return Math.max(0, round.endTime - TimeSync.serverTime());
    }

    // Milliseconds until start of next round, if any
    static breakRemainingTime() {
      let nextRound, round;
      if ((round = TurkServer.currentRound()) == null) { return; }
      const now = Date.now();
      if ((round.startTime <= now) && (round.endTime >= now)) {
        // if we are not at a break, return 0
        return 0;
      }

      // if we are at a break, we already set next round to be active.
      if ((nextRound = RoundTimers.findOne({index: round.index + 1})) == null) { return; }
      if (nextRound.startTime == null) { return; }
      return Math.max(0, nextRound.startTime - TimeSync.serverTime());
    }
  });
  Cls.initClass();
  return Cls;
})();

// Register all the helpers in the form tsGlobalHelperTime
for (var key of Object.keys(TurkServer.Timers || {})) {
  // camelCase the helper name
  var helperName = "ts" + key.charAt(0).toUpperCase() + key.slice(1);
  (function() { // Bind the function to the current value inside the closure
    const func = TurkServer.Timers[key];
    return UI.registerHelper(helperName, function() {
      return TurkServer.Util.formatMillis(func.apply(this, arguments));
  });
  })();
}

function __guard__(value, transform) {
  return (typeof value !== 'undefined' && value !== null) ? transform(value) : undefined;
}