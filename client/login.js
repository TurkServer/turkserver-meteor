// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS103: Rewrite code to no longer use __guard__
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const unescapeURL = s => decodeURIComponent(s.replace(/\+/g, "%20"));

const getURLParams = function() {
  const params = {};
  const m = window.location.href.match(/[\\?&]([^=]+)=([^&#]*)/g);
  if (m) {
    let i = 0;
    while (i < m.length) {
      const a = m[i].match(/.([^=]+)=(.*)/);
      params[unescapeURL(a[1])] = unescapeURL(a[2]);
      i++;
    }
  }
  return params;
};

const params = getURLParams();

const hitIsViewing = params.assignmentId && params.assignmentId === "ASSIGNMENT_ID_NOT_AVAILABLE";

// UI helpers for login
UI.registerHelper("hitParams", params);
UI.registerHelper("hitIsViewing", hitIsViewing);

// Subscribe to the currently viewed batch if in the preview page
// TODO: allow for reading meta properties later as well
if (hitIsViewing && params.batchId != null) {
  Meteor.subscribe("tsLoginBatches", params.batchId);
}

const loginCallback = function(err) {
  if (!err) {
    return;
  }
  console.log(err);
  if (err.reason === ErrMsg.alreadyCompleted) {
    // submit the HIT
    return TurkServer.submitHIT();
  } else {
    // Make sure to display this after client fully loads; otherwise error may
    // not appear. (However, log out immediately as below.)
    Meteor.startup(() =>
      bootbox.dialog({
        closeButton: false,
        message: "<p>Unable to login:</p>" + err.message
      })
    );

    // TODO: make this a bit more robust
    // Log us out even if the resume token logged us in; copied from
    // https://github.com/meteor/meteor/blob/devel/packages/accounts-base/accounts_client.js#L195
    Accounts.connection.setUserId(null);
    return (Accounts.connection.onReconnect = null);
  }
};

const mturkLogin = args =>
  Accounts.callLoginMethod({
    methodArguments: [args],
    userCallback: loginCallback
  });

let loginDialog = null;

Template.tsTestingLogin.events = {
  "submit form"(e, tmpl) {
    e.preventDefault();
    const batchId = tmpl.find("select[name=batch]").value;
    if (!batchId) {
      return;
    }
    console.log("Trying login with testing credentials");
    // Save parameters (including generated stuff) and login
    const loginParams = _.extend(this, {
      batchId,
      test: true
    });

    Session.set("_loginParams", loginParams);
    mturkLogin(loginParams);

    if (loginDialog != null) {
      loginDialog.modal("hide");
    }
    return (loginDialog = null);
  }
};

// Subscribe to the list of batches only when this dialog is open
Template.tsTestingLogin.rendered = function() {
  return (this.subHandle = Meteor.subscribe("tsLoginBatches"));
};

Template.tsTestingLogin.destroyed = function() {
  return this.subHandle.stop();
};

Template.tsTestingLogin.helpers({
  batches() {
    return Batches.find();
  }
});

const testLogin = function() {
  // FIXME hack: never run this if we are live
  if (hitIsViewing) {
    return;
  }
  if (window.location.protocol === "https:" || window !== window.parent) {
    return;
  }
  // Don't try logging in if we are logged in or already have parameters
  if (Meteor.userId() || Session.get("_loginParams")) {
    return;
  }
  // Don't show this if we are trying to get at the admin interface
  if (__guard__(__guard__(Router.current(), x1 => x1.url), x => x.indexOf("/turkserver")) === 0) {
    return;
  }

  const str = Random.id();
  const data = {
    hitId: str + "_HIT",
    assignmentId: str + "_Asst",
    workerId: str + "_Worker"
  };

  loginDialog = TurkServer._displayModal(Template.tsTestingLogin, data, {
    title: "Select batch",
    message: " "
  });
};

// Remember our previous hit parameters unless they have been replaced
// TODO make sure this doesn't interfere with actual HITs
if (params.hitId && params.assignmentId && params.workerId) {
  Session.set("_loginParams", {
    hitId: params.hitId,
    assignmentId: params.assignmentId,
    workerId: params.workerId,
    batchId: params.batchId,
    // TODO: hack to allow testing logins
    test: params.test != null || params.workerId.indexOf("_Worker") >= 0
  });
  Meteor._debug("Captured login params");
}

// Recover either page params or stored session params as above
const loginParams = Session.get("_loginParams");

if (loginParams) {
  Meteor._debug("Logging in with captured or stored parameters");
  mturkLogin(loginParams);
} else {
  // Give enough time to log in some other way before showing login dialog
  TurkServer._delayedStartup(testLogin, 1000);
}

// TODO Testing disconnect and reconnect, remove later
TurkServer.testingLogin = function() {
  if (Meteor.user()) {
    console.log("Already logged in.");
    return;
  }
  if (!Session.get("_loginParams")) {
    console.log("No parameters saved.");
    return;
  }
  return mturkLogin(Session.get("_loginParams"));
};

function __guard__(value, transform) {
  return typeof value !== "undefined" && value !== null ? transform(value) : undefined;
}
