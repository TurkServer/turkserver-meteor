// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS205: Consider reworking code to avoid use of IIFEs
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
import { Meteor } from "meteor/meteor";

import { ErrMsg } from "../lib/common";
import { Assignment } from "./assignment";
import { Instance } from "./instance";
import { Accounts } from "meteor/accounts-base";

const attemptCallbacks = (callbacks, context, errMsg) =>
  Array.from(callbacks).map(cb =>
    (() => {
      try {
        return cb.call(context);
      } catch (e) {
        return Meteor._debug(errMsg, e);
      }
    })()
  );

const connectCallbacks = [];
const disconnectCallbacks = [];
const idleCallbacks = [];
const activeCallbacks = [];

TurkServer.onConnect = func => connectCallbacks.push(func);
TurkServer.onDisconnect = func => disconnectCallbacks.push(func);
TurkServer.onIdle = func => idleCallbacks.push(func);
TurkServer.onActive = func => activeCallbacks.push(func);

// When getting user records in a session callback, we have to check if admin
const getUserNonAdmin = function(userId) {
  const user = Meteor.users.findOne(userId);
  if (user == null || (user != null ? user.admin : undefined)) {
    return;
  }
  return user;
};

/*
  Connect/disconnect callbacks

  In the methods below, we use Partitioner.getUserGroup(userId) because
  user.group takes a moment to be propagated.
*/
const sessionReconnect = function(doc) {
  if (getUserNonAdmin(doc.userId) == null) {
    return;
  }

  const asst = Assignment.getCurrentUserAssignment(doc.userId);

  // TODO possible debug message, but probably caught below.
  if (asst == null) {
    return;
  }

  // Save IP address and UA; multiple connections from different IPs/browsers
  // are recorded for diagnostic purposes.
  return asst._update({
    $addToSet: {
      ipAddr: doc.ipAddr,
      userAgent: doc.userAgent
    }
  });
};

const userReconnect = function(user) {
  let groupId;
  const asst = Assignment.getCurrentUserAssignment(user._id);

  if (asst == null) {
    Meteor._debug(`${user._id} reconnected but has no active assignment`);
    // TODO maybe kick this user out and show an error
    return;
  }

  // Ensure user is in a valid state; add to lobby if not
  const state = user.turkserver != null ? user.turkserver.state : undefined;
  if (state === "lobby" || state == null) {
    asst._enterLobby();
    return;
  }

  // We only call the group operations below if the user was in a group at the
  // time of connection
  if ((groupId = Partitioner.getUserGroup(user._id)) == null) {
    return;
  }
  asst._reconnected(groupId);

  return Instance.getInstance(groupId).bindOperation(
    function() {
      TurkServer.log({
        _userId: user._id,
        _meta: "connected"
      });

      attemptCallbacks(connectCallbacks, this, "Exception in user connect callback");
    },
    {
      userId: user._id,
      event: "connected"
    }
  );
};

const userDisconnect = function(user) {
  let groupId;
  const asst = Assignment.getCurrentUserAssignment(user._id);

  // If they are disconnecting after completing an assignment, there will be no
  // current assignment.
  if (asst == null) {
    return;
  }

  // If user was in lobby, remove them
  asst._removeFromLobby();

  if ((groupId = Partitioner.getUserGroup(user._id)) == null) {
    return;
  }
  asst._disconnected(groupId);

  return Instance.getInstance(groupId).bindOperation(
    function() {
      TurkServer.log({
        _userId: user._id,
        _meta: "disconnected"
      });

      attemptCallbacks(disconnectCallbacks, this, "Exception in user disconnect callback");
    },
    {
      userId: user._id,
      event: "disconnected"
    }
  );
};

/*
  Idle and returning from idle
*/

const userIdle = function(user) {
  let groupId;
  if ((groupId = Partitioner.getUserGroup(user._id)) == null) {
    return;
  }

  const asst = Assignment.getCurrentUserAssignment(user._id);
  asst._isIdle(groupId, user.status.lastActivity);

  return Instance.getInstance(groupId).bindOperation(
    function() {
      TurkServer.log({
        _userId: user._id,
        _meta: "idle",
        _timestamp: user.status.lastActivity
      }); // Overridden to a past value

      attemptCallbacks(idleCallbacks, this, "Exception in user idle callback");
    },
    {
      userId: user._id,
      event: "idle"
    }
  );
};

// Because activity on any session will make a user active, we use this in
// order to properly record the last activity time on the client
const sessionActive = function(doc) {
  let groupId;
  if (getUserNonAdmin(doc.userId) == null) {
    return;
  }

  if ((groupId = Partitioner.getUserGroup(doc.userId)) == null) {
    return;
  }

  const asst = Assignment.getCurrentUserAssignment(doc.userId);
  asst._isActive(groupId, doc.lastActivity);

  return Instance.getInstance(groupId).bindOperation(
    function() {
      TurkServer.log({
        _userId: doc.userId,
        _meta: "active",
        _timestamp: doc.lastActivity
      }); // Also overridden

      attemptCallbacks(activeCallbacks, this, "Exception in user active callback");
    },
    {
      userId: doc.userId,
      event: "active"
    }
  );
};

/*
  Hook up callbacks to events and observers
*/

UserStatus.events.on("connectionLogin", sessionReconnect);
// Logout / Idle are done at user level
UserStatus.events.on("connectionActive", sessionActive);

// This is triggered from individual connection changes via multiplexing in
// user-status. Note that `observe` is used instead of `observeChanges` because
// we're interested in the contents of the entire user document when someone goes
// online/offline or idle/active.
Meteor.startup(function() {
  Meteor.users
    .find({
      admin: { $exists: false }, // Excluding admin
      "status.online": true // User is online
    })
    .observe({
      added: userReconnect,
      removed: userDisconnect
    });

  return Meteor.users
    .find({
      admin: { $exists: false }, // Excluding admin
      "status.idle": true // User is idle
    })
    .observe({
      added: userIdle
    });
});

/*
  Test handlers - assuming user-status is working correctly, we create these
  convenience functions for testing users coming online and offline

  TODO: we might want to make these tests end-to-end so that they ensure all of
  the user-status functionality is working as well.
*/
TestUtils.connCallbacks = {
  sessionReconnect(doc) {
    sessionReconnect(doc);
    return userReconnect(Meteor.users.findOne(doc.userId));
  },

  sessionDisconnect(doc) {
    return userDisconnect(Meteor.users.findOne(doc.userId));
  },

  sessionIdle(doc) {
    // We need to set the status.lastActivity field here, as in user-status,
    // because the callback expects to read its value
    Meteor.users.update(doc.userId, {
      $set: { "status.lastActivity": doc.lastActivity }
    });

    return userIdle(Meteor.users.findOne(doc.userId));
  },

  sessionActive
};

/*
  Methods
*/

Meteor.methods({
  "ts-set-username"(username) {
    // TODO may need validation here due to bad browsers/bad people
    const userId = Meteor.userId();
    if (!userId) {
      return;
    }

    // No directOperation needed here since partitioner recognizes username as
    // a unique index
    if (Meteor.users.findOne({ username }) != null) {
      throw new Meteor.Error(409, ErrMsg.usernameTaken);
    }

    return Meteor.users.update(userId, { $set: { username } });
  },

  "ts-submit-exitdata"(doc, panel) {
    let token;
    const userId = Meteor.userId();
    if (!userId) {
      throw new Meteor.Error(403, ErrMsg.authErr);
    }

    // TODO what if this doesn't exist?
    const asst = Assignment.currentAssignment();
    // mark assignment as completed and save the data
    asst.setCompleted(doc);

    // Update worker contact info
    // TODO update API for writing panel data.
    // TODO don't overwrite panel data if we don't need to.
    if (panel != null) {
      asst.setWorkerData({
        contact: panel.contact,
        available: {
          times: panel.times,
          updated: new Date()
        }
      });
    }

    // Destroy the token for this connection, so that a resume login will not
    // be used for future HITs. Returning true should cause the HIT to submit on
    // the client side, but if that doesn't work, the user will be logged out.
    if ((token = Accounts._getLoginToken(this.connection.id))) {
      // This $pulls tokens from services.resume.loginTokens, and should work
      // in the same way that Accounts._expireTokens effects cleanup.
      Accounts.destroyToken(userId, token);
    }

    // return true to auto submit the HIT
    return true;
  }
});
