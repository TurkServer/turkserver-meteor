/**
 * @summary Utilities for controlling round timers within instances.
 * @namespace
 */
class Timers {

  /**
   * @summary Starts a new round in the current instance.
   * @function TurkServer.Timers.startNewRound
   * @locus Server
   * @param {Date} startTime time which can be in the future.
   * @param {Date} endTime time by which the round is ended automatically.
   */
  static startNewRound(startTime, endTime) {

  }

  /**
   * @summary End the current round.
   * @function TurkServer.Timers.endCurrentRound
   */
  static endCurrentRound() {

  }

  /**
   * @summary Call a function when a round ends, either due to a timeout or
   * manual trigger.
   * @function TurkServer.Timers.onRoundEnd
   * @param {Function} func The function to call when a round ends.
   */
  static onRoundEnd(func) {

  }
}

// TurkServer.Timers = Timers;
