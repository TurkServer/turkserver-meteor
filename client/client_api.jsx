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
  if ( !TurkServer.inExperiment() ) return false;

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
