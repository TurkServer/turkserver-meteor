const _round_handlers = [];

/**
 * @summary Indicates that a round ended due to the timer running out.
 * @constant {string} TurkServer.Timers.ROUND_END_TIMEOUT
 */
const ROUND_END_TIMEOUT = "timeout";

/**
 * @summary Indicates that a round ended from manually calling.
 * `endCurrentRound`.
 * @constant {string} TurkServer.Timers.ROUND_END_MANUAL
 */
const ROUND_END_MANUAL = "currentend";

/**
 * @summary Indicates that a round ended from directly starting a new round.
 * @constant {string} TurkServer.Timers.ROUND_END_NEWROUND
 */
const ROUND_END_NEWROUND = "newstart";

/**
 * @summary Utilities for controlling round timers within instances.
 * @namespace
 */
class Timers {

  /**
   * @summary Starts a new round in the current instance.
   * @function TurkServer.Timers.startNewRound
   * @locus Server
   * @param {Date} startTime Time which can be in the future. If it is in the
   * past, it will be automatically clamped to the current time.
   * @param {Date} endTime Time by which the round is ended automatically.
   */
  static startNewRound(startTime, endTime) {
    check(startTime, Date);
    check(endTime, Date);

    let now = new Date();

    if (endTime < now) {
      throw new Error("endTime is in the past");
    }

    // Clamp startTime if it is in the past
    if (startTime < now) {
      startTime = now;
    }

    // Is there a current round in progress? If so, end it
    let currentRound = null, index = 1;
    if( (currentRound = RoundTimers.findOne({ended: false})) != null ) {
      index = currentRound.index + 1;

      // If we didn't end this round, we shouldn't try to start a new one
      if( !tryEndingRound(currentRound._id, ROUND_END_NEWROUND, now) ) {
        throw new Error(
          "Possible multiple concurrent calls to startNewRound detected.")
      }
    }

    // Schedule next round
    // This may fail if this method was called too quickly
    try {
      const newRoundId = RoundTimers.insert({
        index,
        startTime,
        endTime,
        ended: false
      });

      scheduleRoundEnd(Partitioner.group(), newRoundId, endTime);
    }
    catch (e) {
      throw new Error(
        "Possible multiple concurrent calls to startNewRound detected.")
    }
  }

  /**
   * @summary End the current round. If called before a scheduled round end,
   * will end the round now.
   * @function TurkServer.Timers.endCurrentRound
   */
  static endCurrentRound() {
    let now = new Date();
    const current = RoundTimers.findOne({ended: false});

    if( current == null ) {
      throw new Error("No current round to end");
    }

    if ( !tryEndingRound(current._id, ROUND_END_MANUAL, now) ) {
      throw new Error(
        "Possible multiple concurrent calls to endCurrentRound detected.");
    }
  }

  /**
   * @summary Call a function when a round ends, either due to a timeout or
   * manual trigger.
   * @function TurkServer.Timers.onRoundEnd
   * @param {Function} func The function to call when a round ends. The
   * function will be called with a single argument indicating the reason
   * the round ended, either
   * TurkServer.Timers.NEW_ROUND_TIMEOUT,
   * TurkServer.Timers.NEW_ROUND_MANUAL, or
   * TurkServer.Timers.NEW_ROUND_NEWROUND.
   */
  static onRoundEnd(func) {
    _round_handlers.push(func);
  }
}

function scheduleRoundEnd(groupId, roundId, endTime) {
  // Clamp interval to 0 if it is negative (i.e. due to CPU lag)
  const interval = Math.max(endTime - Date.now(), 0);

  // currentInvocation is removed, so we must bind the group ourselves if we
  // were called from inside a method:
  // https://github.com/meteor/meteor/blob/devel/packages/meteor/timers.js
  TestUtils.lastScheduledRound = Meteor.setTimeout(function() {
    Partitioner.bindGroup(groupId, function() {
      tryEndingRound(roundId, ROUND_END_TIMEOUT);
    });
  }, interval);
}

// XXX always call this function within a partitioner context.
function tryEndingRound(roundId, endType, endTime = null) {
  const update = { ended: true };
  if (endTime != null) update.endTime = endTime;

  const ups  = RoundTimers.update({
    _id: roundId,
    ended: false
  }, {
    $set: update
  });

  // If the round with this id already ended somehow, don't call handlers
  if (ups === 0) return false;

  // Succeeded - call handlers with the round end type
  for( handler of _round_handlers ) {
    handler.call(null, endType);
  }
  return true;
}

// When restarting server, re-schedule all un-ended rounds
function scheduleOutstandingRounds() {
  let scheduled = 0;

  RoundTimers.direct.find({ended: false}).forEach( (round) => {
    scheduleRoundEnd(round._groupId, round._id, round.endTime);
    scheduled++;
  });

  if (scheduled > 0) {
    Meteor._debug(`Scheduled the end of ${scheduled} unfinished rounds`);
  }
}

Meteor.startup(scheduleOutstandingRounds);

/*
  Exports
 */
Timers.ROUND_END_TIMEOUT = ROUND_END_TIMEOUT;
Timers.ROUND_END_MANUAL = ROUND_END_MANUAL;
Timers.ROUND_END_NEWROUND = ROUND_END_NEWROUND;

TurkServer.Timers = Timers;

/*
  Testing functions
 */
TestUtils.clearRoundHandlers = function () {
  _round_handlers.length = 0;
};

TestUtils.scheduleOutstandingRounds = scheduleOutstandingRounds;
