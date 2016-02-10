const mturk = Npm.require('mturk-api');
const JSPath = Npm.require('jspath');

let api = undefined;

if ( !TurkServer.config.mturk.accessKeyId ||
    !TurkServer.config.mturk.secretAccessKey ) {
  Meteor._debug("Missing Amazon API keys for connecting to MTurk. Please configure.");
} else {
  const config = {
    access: TurkServer.config.mturk.accessKeyId,
    secret: TurkServer.config.mturk.secretAccessKey,
    sandbox: TurkServer.config.mturk.sandbox
  };

  const promise = mturk.connect(config)
    .then((api) => api)
    .catch(console.error);
  api = Promise.resolve(promise).await();
}

TurkServer.mturk = function(op, params) {
  if (!api) {
    console.log("Ignoring operation " + op + " because MTurk is not configured.");
    return;
  }

  const promise = api.req(op, params).then((resp) => resp);
  const result = Promise.resolve(promise).await();

  return transform(op, result);
};

/*
  Translate results to be a little more similar to the original code:
  https://github.com/jefftimesten/mturk/blob/master/index.js

  Docs at https://github.com/dfilatov/jspath:
  expressions always return an array;
  with [0] at the end return the first match.

  XXX we may not necessarily want to continue using these in the future.
   This is just for compatibility with what the previous API returned.
 */
function transform(op, result) {
  switch(op) {
    case "CreateHIT":
      return JSPath.apply("..HITId[0]", result);
    case "GetAccountBalance":
      return JSPath.apply("..GetAccountBalanceResult.AvailableBalance.Amount[0]", result);
    case "GetAssignment":
      return JSPath.apply("..Assignment[0]", result);
    case "GetAssignmentsForHIT":
      return JSPath.apply("..GetAssignmentsForHITResult", result);
    case "GetHIT":
      return JSPath.apply("..HIT[0]", result);
    case "GetReviewableHITs":
      return JSPath.apply("..GetReviewableHITsResult", result);
    case "RegisterHITType":
      return JSPath.apply("..HITTypeId[0]", result);
    case "SearchHITs":
      return JSPath.apply("..SearchHITsResult", result);
  }

  return result;
}

TurkServer.Util = TurkServer.Util || {};

TurkServer.Util.assignQualification = function(workerId, qualId, value, notify=true) {
  check(workerId, String);
  check(qualId, String);
  check(value, Match.Integer);

  if (Workers.findOne(workerId) == null) {
    throw new Error("Unknown worker");
  }

  if (Workers.findOne({
      _id: workerId,
      "quals.id": qualId
    }) != null) {

    TurkServer.mturk("UpdateQualificationScore", {
      SubjectId: workerId,
      QualificationTypeId: qualId,
      IntegerValue: value
    });
    Workers.update({
      _id: workerId,
      "quals.id": qualId
    }, {
      $set: {
        "quals.$.value": value
      }
    });

  } else {

    TurkServer.mturk("AssignQualification", {
      WorkerId: workerId,
      QualificationTypeId: qualId,
      IntegerValue: value,
      SendNotification: notify
    });
    Workers.update(workerId, {
      $push: {
        quals: {
          id: qualId,
          value: value
        }
      }
    });

  }
};

Meteor.startup(function() {
  Qualifications.upsert({
    name: "US Worker"
  }, {
    $set: {
      QualificationTypeId: "00000000000000000071",
      Comparator: "EqualTo",
      LocaleValue: "US"
    }
  });
  Qualifications.upsert({
    name: "US or CA Worker"
  }, {
    $set: {
      QualificationTypeId: "00000000000000000071",
      Comparator: "In",
      LocaleValue: ["US", "CA"]
    }
  });
  Qualifications.upsert({
    name: "> 100 HITs"
  }, {
    $set: {
      QualificationTypeId: "00000000000000000040",
      Comparator: "GreaterThan",
      IntegerValue: "100"
    }
  });
  Qualifications.upsert({
    name: "95% Approval"
  }, {
    $set: {
      QualificationTypeId: "000000000000000000L0",
      Comparator: "GreaterThanOrEqualTo",
      IntegerValue: "95"
    }
  });
  Qualifications.upsert({
    name: "Adult Worker"
  }, {
    $set: {
      QualificationTypeId: "00000000000000000060",
      Comparator: "EqualTo",
      IntegerValue: "1"
    }
  });
});
