/**
 * @summary Access treatment data assigned to the current user or the user's current world. A reactive variable.
 * @locus Client
 * @param [String] {name} The name of the specific treatment to query for. If not specified, returns data for all treatments.
 * @returns {Object} treatment key/value pairs
 */
TurkServer.treatment = function(name) {
  if (name != null) {
    return Treatments.findOne(
      { name },
      {
        fields: { _id: 0 }
      }
    );
  }

  // Merge all treatments into one document
  return TurkServer._mergeTreatments(Treatments.find({}));
};

/**
 * @summary Reactive state variable for whether the user is in the lobby.
 * @locus Client
 * @returns {Boolean} true if user is in lobby.
 */
TurkServer.inLobby = function() {
  return Session.equals("turkserver.state", "lobby");
};

/**
 * @summary Reactive state variable for whether the user is in an experiment instance.
 * @locus Client
 * @returns {Boolean} true if the user is in an experiment
 */
TurkServer.inExperiment = function() {
  return Session.equals("turkserver.state", "experiment");
};

/**
 * @summary Reactive variable denoting whether the user is in a completed
 * instance, before returning to the lobby.
 * @locus Client
 * @returns {Boolean} true if the user is in a completed experiment
 */
TurkServer.instanceEnded = function() {
  if (!TurkServer.inExperiment()) return false;

  const currentExp = Experiments.findOne();
  return currentExp && currentExp.endTime != null;
};

/**
 * @summary Reactive state variable for whether the user is in the exit survey (pre-submission).
 * @locus Client
 * @returns {Boolean} true if in the exit survey
 */
TurkServer.inExitSurvey = function() {
  return Session.equals("turkserver.state", "exitsurvey");
};

/**
 * @summary The current payment on the user's session; a reactive variable.
 * In MTurk, this is the HIT bonus.
 * @locus Client
 * @returns {Number} The current payment amount.
 */
TurkServer.currentPayment = function() {
  const asst = Assignments.findOne();
  return asst && asst.bonusPayment;
};

/**
 * @summary The current round within the scoped instance. Within the break
 * between rounds, this is defined as the last active round.
 * @locus Client
 * @returns {Object} object containing the fields <code>index</code>,
 * <code>startTime</code>, and <code>endTime</code>.
 */
TurkServer.currentRound = function() {
  let activeRound = RoundTimers.findOne({ ended: false });

  // TODO this polls every second, which can be quite inefficient. Could be improved.
  if (activeRound && activeRound.startTime <= TimeSync.serverTime()) {
    return activeRound;
  }

  // Return the round before this one, if any
  if (activeRound != null) {
    return RoundTimers.findOne({ index: activeRound.index - 1 });
  }

  // If no active round and no round scheduled, return the highest one
  return RoundTimers.findOne({}, { sort: { index: -1 } });
};

// Called to start the monitor with given settings when in experiment
// Similar to usage in user-status demo:
// https://github.com/mizzao/meteor-user-status
function safeStartMonitor(threshold, idleOnBlur) {
  // We run this in an autorun block because it may fail on startup if time
  // is not synced. As soon as it succeeds, we are done.
  // See https://github.com/mizzao/meteor-user-status/blob/master/monitor.coffee
  const settings = { threshold, idleOnBlur };

  Tracker.autorun(c => {
    try {
      UserStatus.startMonitor(settings);
      c.stop();
      console.log("Idle monitor started with ", settings);
    } catch (e) {}
  });
}

function stopMonitor() {
  if (Deps.nonreactive(UserStatus.isMonitoring)) {
    UserStatus.stopMonitor();
  }
}

// This Tracker Computation starts and stops idle monitoring as the user
// enters/exits an experiment
let idleComp = null;

/**
 * @summary Stop idle monitoring, if it's currently enabled.
 * @locus Client
 */
TurkServer.disableIdleMonitor = function() {
  if (idleComp != null) {
    idleComp.stop();
    stopMonitor();
  }
};

/**
 * @summary Start idle monitoring on the client with specific settings,
 * automatically activating and deactivating as the user enters experiment
 * instances.
 *
 * See {@link https://github.com/mizzao/meteor-user-status} for detailed
 * meanings of the parameters.
 *
 * @locus Client
 * @param threshold Time of inaction before a user is considered inactive.
 * @param idleOnBlur Whether to count window blurs as inactivity.
 */
TurkServer.enableIdleMonitor = function(threshold, idleOnBlur) {
  // If monitor is already started, stop it before trying new settings
  TurkServer.disableIdleMonitor();

  idleComp = Deps.autorun(() => {
    if (TurkServer.inExperiment()) {
      // This is reactive
      safeStartMonitor(threshold, idleOnBlur);
    } else {
      stopMonitor();
    }
  });
};

/*
 * Currently internal functions
 */
// Run a function some time after Meteor.startup
TurkServer._delayedStartup = function(func, delay) {
  Meteor.startup(function() {
    Meteor.setTimeout(func, delay);
  });
};
