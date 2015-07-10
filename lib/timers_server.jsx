const _round_handlers = [];

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

    let now = new Date();

    if (endTime - now < 0) {
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

      RoundTimers.update(currentRound._id, {
         $set: {
           ended: true,
           endTime: now
         }
      });
    }

    // Schedule next round
    RoundTimers.insert({
      index,
      startTime,
      endTime,
      ended: false
    });

    scheduleRoundEnd( Partitioner.group(), index, endTime );
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

    // Update endTime to be whatever the new time is
    RoundTimers.update( current._id, {
      $set: {
        ended: true,
        endTime: now
      }
    });

    processRoundEnd();
  }

  /**
   * @summary Call a function when a round ends, either due to a timeout or
   * manual trigger.
   * @function TurkServer.Timers.onRoundEnd
   * @param {Function} func The function to call when a round ends.
   */
  static onRoundEnd(func) {
    _round_handlers.push(func);
  }
}

function scheduleRoundEnd(groupId, index, endTime) {
  // Clamp interval to 0 if it is negative (i.e. due to CPU lag)
  const interval = Math.max(endTime - Date.now(), 0);

  // currentInvocation is removed, so we must bind the group ourselves if we
  // were called from inside a method:
  // https://github.com/meteor/meteor/blob/devel/packages/meteor/timers.js
  TestUtils.lastScheduledRound = Meteor.setTimeout(function() {
    Partitioner.bindGroup(groupId, function() {
      // Try to end the round with this index and time. If not already ended,
      // then process the current round end.
      const up = RoundTimers.update({
        index,
        // probably only one of these is necessary
        endTime,
        ended: false
      }, {
        $set: {
          ended: true
        }
      });

      // If document was updated, then handle the round end here.
      if( up > 0 ) processRoundEnd();

    });
  }, interval);
}

// XXX always call this function within a partitioner context.
function processRoundEnd() {
  for( handler of _round_handlers ) {
    handler.call();
  }
}

// When restarting server, re-schedule all un-ended rounds
function scheduleOutstandingRounds() {
  let scheduled = 0;

  RoundTimers.direct.find({ended: false}).forEach( (round) => {
    scheduleRoundEnd(round._groupId, round.index, round.endTime);
    scheduled++;
  });

  if (scheduled > 0) {
    Meteor._debug(`Scheduled the end of ${scheduled} unfinished rounds`);
  }
}

Meteor.startup(scheduleOutstandingRounds);

TurkServer.Timers = Timers;

TestUtils.clearRoundHandlers = function () {
  _round_handlers.length = 0;
};

TestUtils.scheduleOutstandingRounds = scheduleOutstandingRounds;
