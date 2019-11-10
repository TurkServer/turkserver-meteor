if (!TurkServer.config.mturk.accessKeyId || !TurkServer.config.mturk.secretAccessKey) {
  Meteor._debug("Missing Amazon API keys for connecting to MTurk. Please configure.");
} else {
  AWS.config = {
    accessKeyId: TurkServer.config.mturk.accessKeyId,
    secretAccessKey: TurkServer.config.mturk.secretAccessKey,
    region: "us-east-1",
    sslEnabled: "true"
  };

  const endpoint = TurkServer.config.mturk.sandbox
    ? "https://mturk-requester-sandbox.us-east-1.amazonaws.com"
    : "https://mturk-requester.us-east-1.amazonaws.com";

  TurkServer.mturk = new AWS.MTurk({ endpoint });
}

TurkServer.Util = TurkServer.Util || {};

TurkServer.Util.assignQualification = function(workerId, qualId, value, notify = true) {
  check(workerId, String);
  check(qualId, String);
  check(value, Match.Integer);

  if (Workers.findOne(workerId) == null) {
    throw new Error("Unknown worker");
  }

  if (
    Workers.findOne({
      _id: workerId,
      "quals.id": qualId
    }) != null
  ) {
    TurkServer.mturk("UpdateQualificationScore", {
      SubjectId: workerId,
      QualificationTypeId: qualId,
      IntegerValue: value
    });
    Workers.update(
      {
        _id: workerId,
        "quals.id": qualId
      },
      {
        $set: {
          "quals.$.value": value
        }
      }
    );
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
  Qualifications.upsert(
    {
      name: "US Worker"
    },
    {
      $set: {
        QualificationTypeId: "00000000000000000071",
        Comparator: "EqualTo",
        LocaleValue: "US"
      }
    }
  );
  Qualifications.upsert(
    {
      name: "US or CA Worker"
    },
    {
      $set: {
        QualificationTypeId: "00000000000000000071",
        Comparator: "In",
        LocaleValue: ["US", "CA"]
      }
    }
  );
  Qualifications.upsert(
    {
      name: "> 100 HITs"
    },
    {
      $set: {
        QualificationTypeId: "00000000000000000040",
        Comparator: "GreaterThan",
        IntegerValue: "100"
      }
    }
  );
  Qualifications.upsert(
    {
      name: "95% Approval"
    },
    {
      $set: {
        QualificationTypeId: "000000000000000000L0",
        Comparator: "GreaterThanOrEqualTo",
        IntegerValue: "95"
      }
    }
  );
  Qualifications.upsert(
    {
      name: "Adult Worker"
    },
    {
      $set: {
        QualificationTypeId: "00000000000000000060",
        Comparator: "EqualTo",
        IntegerValue: "1"
      }
    }
  );
});
