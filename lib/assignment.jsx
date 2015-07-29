const _assignments = {};
const _userAssignments = {};

// When an assignment goes from assigned to completed or returned, remove
// the assignment object from the user assignment cache.

// XXX the first query might be a little slow due to not having an index,
// but it will run quickly for subsequent live updates.
Assignments.find({status: "assigned"}, {fields: {workerId: 1}}).observe({
   removed: function(asstDoc) {
     const user = Meteor.users.findOne({workerId: asstDoc.workerId});
     if( user != null ) delete _userAssignments[user._id];
   }
});

/**
 * @summary An assignment captures the lifecycle of a user assigned to a HIT.
  * In the future, it may be generalized to represent the entire connection of
  * a user from any source.
 * @class TurkServer.Assignment
 * @instancename assignment
 */
class Assignment {

  static createAssignment(data) {
    const asstId = Assignments.insert(data);
    return _assignments[asstId] = new Assignment(asstId, data);
  }

  /**
   *
   * @param asstId
   * @returns {*}
   */
  static getAssignment(asstId) {
    let asst = _assignments[asstId];
    if( asst != null ) return asst;

    const data = Assignments.findOne(asstId);
    if (data == null) throw new Error(`Assignment ${asstId} doesn't exist`);

    // Check again for an assignment being created during yield
    asst = _assignments[asstId];
    if (asst == null) {
      asst = _assignments[asstId] = new Assignment(asstId, data);
    }

    return asst;
  }

  static getCurrentUserAssignment(userId) {
    // Check for cached assignment
    let asst = _userAssignments[userId];
    if (asst != null ) return asst;

    let user = Meteor.users.findOne(userId);

    if( user == null || user.workerId == null ) return;

    let asstData = Assignments.findOne({
      workerId: user.workerId,
      status: "assigned"
    });

    if (asstData != null) {
      // Cache assignment and return
      return _userAssignments[userId] = Assignment.getAssignment(asstData._id);
    }
    // return null
  }

  static currentAssignment() {
    let userId = Meteor.userId();
    if (userId == null) return;
    return Assignment.getCurrentUserAssignment(userId);
  }

  constructor(asstId, props) {
    check(asstId, String);

    if ( _assignments[asstId] != null ) {
      throw new Error(`Assignment ${asstId} already exists; use getAssignment`);
    }

    let {
      batchId,
      hitId,
      assignmentId,
      workerId
      } = props || Assignments.findOne(asstId);

    check(batchId, String);
    check(hitId, String);
    check(assignmentId, String);
    check(workerId, String);

    // These properties are invariant for any assignment, so we can store
    // them on the object.
    this.asstId = asstId;

    this.batchId = batchId;
    this.hitId = hitId;
    this.assignmentId = assignmentId;
    this.workerId = workerId;

    // Grab the userId.
    // When the assignment is constructed as part of a method call, we need to
    // reach around it to avoid adding a group key, which will cause the find to
    // fail.
    this.userId = Meteor.users.direct.findOne({
      workerId: this.workerId
    })._id;
  }

  getBatch() {
    return TurkServer.Batch.getBatch(this.batchId);
  }

  getInstances() {
    return Assignments.findOne(this.asstId).instances || [];
  }

  showExitSurvey() {
    Meteor.users.update(this.userId, {
      $set: {
        "turkserver.state": "exitsurvey"
      }
    });
  }

  isCompleted() {
    return Assignments.findOne(this.asstId).status === "completed";
  }

  setCompleted(exitdata) {
    const user = Meteor.users.findOne(this.userId);
    const state = user && user.turkserver && user.turkserver.state;

    // Submitting is only allowed from the exit survey
    if (state !== "exitsurvey") {
      throw new Meteor.Error(403, ErrMsg.stateErr);
    }

    Assignments.update(this.asstId, {
      $set: {
        status: "completed",
        submitTime: new Date(),
        exitdata
      }
    });

    Meteor.users.update(this.userId, {
      $unset: {
        "turkserver.state": null
      }
    });
  }

  /**
   * @summary Mark this assignment as returned and not completable
   */
  setReturned() {
    Assignments.update(this.asstId, {
      $set: {
        status: "returned"
      }
    });

    // Unset the user's state
    // XXX this assumes that there's no way we would have accepted a second
    // assignment from this user in the meantime.
    Meteor.users.update(this.userId, {
      $unset: {
        "turkserver.state": null
      }
    });
  }

  /**
   * @summary Gets the variable payment (bonus) amount for this assignment
   * @returns {*|null|number}
   */
  getPayment() {
    return Assignments.findOne(this.asstId).bonusPayment;
  }

  /**
   * @summary Sets the payment amount for this assignment, replacing any
   * existing value
   * @param amount
   */
  setPayment(amount) {
    check(amount, Match.OneOf(Number, null));

    let modifier;

    if (amount != null) {
      modifier = {
        $set: {
          bonusPayment: amount
        }
      };
    }
    else {
      modifier = {
        $unset: {
          bonusPayment: null
        }
      };
    }

    const update = Assignments.update({
      _id: this.asstId,
      bonusPaid: null
    }, modifier);

    if (update === 0) {
      throw new Error("Can't modify a bonus that was already paid");
    }
  }

  /**
   * @summary Adds (or subtracts) an amount to the payment for this assignment
   * @param amount
   */
  addPayment(amount) {
    check(amount, Number);

    const update = Assignments.update({
      _id: this.asstId,
      bonusPaid: null
    }, {
      $inc: {
        bonusPayment: amount
      }
    });

    if (update === 0) {
      throw new Error("Can't modify a bonus that was already paid");
    }
  }

  /**
   * @summary Get the current MTurk status for this assignment
   */
  refreshStatus() {
    // Since MTurk AssignmentIds may be re-used, it's important we only query
    // for completed assignments.
    if ( !this.isCompleted() ) {
      throw new Error("Assignment not completed");
    }

    let asstData;

    try {
      asstData = TurkServer.mturk("GetAssignment", {
        AssignmentId: this.assignmentId
      });
    } catch (e) {
      throw new Meteor.Error(500, e.toString());
    }

    // XXX Just in case, check that it's actually the same worker here,
    // and not a reassignment to someone else.
    if ( this.workerId !== asstData.WorkerId ) {
      throw new Error("Worker ID doesn't match");
    }

    Assignments.update(this.asstId, {
      $set: {
        mturkStatus: asstData.AssignmentStatus
      }
    });

    return asstData.AssignmentStatus;
  }

  _checkSubmittedStatus() {
    if ( !this.isCompleted() ) {
      throw new Error("Assignment not completed");
    }

    const mturkStatus = this._data().mturkStatus;

    if (mturkStatus === "Approved" || mturkStatus === "Rejected") {
      throw new Error("Already approved or rejected");
    }
  }

  approve(message) {
    check(message, String);
    this._checkSubmittedStatus();

    TurkServer.mturk("ApproveAssignment", {
      AssignmentId: this.assignmentId,
      RequesterFeedback: message
    });

    // TODO: If this operation fails due to auto-approval, we should still
    // set the status to approved.

    // If successful, update mturk status to reflect that.
    Assignments.update(this.asstId, {
      $set: {
        mturkStatus: "Approved"
      }
    });
  }

  reject(message) {
    check(message, String);
    this._checkSubmittedStatus();

    TurkServer.mturk("RejectAssignment", {
      AssignmentId: this.assignmentId,
      RequesterFeedback: message
    });

    return Assignments.update(this.asstId, {
      $set: {
        mturkStatus: "Rejected"
      }
    });
  }

  /**
   * @summary Pays the worker their bonus, if set. (using the MTurk API)
   * @param message
   */
  payBonus(message) {
    check(message, String);
    const data = Assignments.findOne(this.asstId);

    if (data.bonusPayment == null) {
      throw new Error("Bonus value not set");
    }

    if (data.bonusPaid != null) {
      throw new Error("Bonus already paid");
    }

    TurkServer.mturk("GrantBonus", {
      WorkerId: data.workerId,
      AssignmentId: data.assignmentId,
      BonusAmount: {
        Amount: data.bonusPayment,
        CurrencyCode: "USD"
      },
      Reason: message
    });

    // Successful payment
    Assignments.update(this.asstId, {
      $set: {
        bonusPaid: new Date(),
        bonusMessage: message
      }
    });
  }

  /**
   * @summary Get data from the worker associated with this assignment.
   * @param field
   * @returns {*}
   */
  getWorkerData(field) {
    const data = Workers.findOne(this.workerId);
    if (field) {
      return data[field];
    } else {
      return data;
    }
  }

  /**
   * @summary Sets data on the worker associated with this assignment.
   * @param props
   */
  setWorkerData(props) {
    Workers.upsert(this.workerId, {
      $set: props
    });
  }

  _data() {
    return Assignments.findOne(this.asstId);
  }

  _update(modifier) {
    return Assignments.update(this.asstId, modifier);
  }

  // Handle an initial connection by this user after accepting a HIT
  // This method is currently purely diagnostic
  _loggedIn() {
    // Is worker in part of an active group (experiment)?
    // This is okay even if batch is not active
    if (Partitioner.getUserGroup(this.userId)) {
      Meteor._debug(`${this.userId} is reconnecting to an existing group`);
      return;
    }

    // Is the worker reconnecting to an exit survey?
    let user = Meteor.users.findOne(this.userId);
    let state = user && user.turkserver && user.turkserver.state;
    if ( state === "exitsurvey") {
      Meteor._debug(`${this.userId} is reconnecting to the exit survey`);
    }

    // Nothing else needs to be done;
    // a fresh login OR a reconnect will check for lobby state properly.
  }

  _enterLobby() {
    const batch = this.getBatch();
    if (batch == null) {
      throw new Meteor.Error(403, "No batch associated with assignment");
    }

    batch.lobby.addAssignment(this);
  }

  _removeFromLobby() {
    const batch = this.getBatch();
    if (batch == null) {
      throw new Meteor.Error(403, "No batch associated with assignment");
    }

    // Removes from lobby if the user is present
    batch.lobby.removeAssignment(this);
  }

  _joinInstance(instanceId) {
    Assignments.update(this.asstId, {
      $push: {
        instances: {
          id: instanceId,
          joinTime: new Date()
        }
      }
    });
  }

  _leaveInstance(instanceId) {
    const now = new Date;
    const updateObj = {
      $set: {
        "instances.$.leaveTime": now
      }
    };

    let discTime, idleTime;
    // If in disconnected state, compute total disconnected time
    if ( (discTime = this._getLastDisconnect(instanceId)) != null) {
      addResetDisconnectedUpdateFields(updateObj, now.getTime() - discTime);
    }
    // If in idle state, compute total idle time
    if ( (idleTime = this._getLastIdle(instanceId)) != null) {
      addResetIdleUpdateFields(updateObj, now.getTime() - idleTime);
    }

    Assignments.update({
      _id: this.asstId,
      "instances.id": instanceId
    }, updateObj);
  }

  // Handle a disconnection by this user
  _disconnected(instanceId) {
    check(instanceId, String);

    // Record a disconnect time if we are currently part of an instance
    const now = new Date();
    updateObj = {
      $set: {
        "instances.$.lastDisconnect": now
      }
    };

    // If we are idle, add the total idle time to the running amount;
    // A new idle session will start when the user reconnects
    let idleTime;
    if (( idleTime = this._getLastIdle(instanceId)) != null ) {
      addResetIdleUpdateFields(updateObj, now.getTime() - idleTime);
    }

    Assignments.update({
      _id: this.asstId,
      "instances.id": instanceId
    }, updateObj);
  }

  // Handle a reconnection by a user, if they were assigned prior to the reconnection
  _reconnected(instanceId) {
    // XXX Safety hatch: never count an idle time tracked over a disconnection
    const updateObj = {
      $unset: {
        "instances.$.lastIdle": null
      }
    };

    let discTime;
    if ( (discTime = this._getLastDisconnect(instanceId)) != null ) {
      addResetDisconnectedUpdateFields(updateObj, Date.now() - discTime);
    }

    Assignments.update({
      _id: this.asstId,
      "instances.id": instanceId
    }, updateObj);
  }

  _isIdle(instanceId, timestamp) {
    // TODO: ignore this update if user is disconnected
    Assignments.update({
      _id: this.asstId,
      "instances.id": instanceId
    }, {
      $set: {
        "instances.$.lastIdle": timestamp
      }
    });
  }

  _isActive(instanceId, timestamp) {
    const idleTime = this._getLastIdle(instanceId);
    if ( !idleTime ) return;

    Assignments.update({
      _id: this.asstId,
      "instances.id": instanceId
    }, addResetIdleUpdateFields({}, timestamp - idleTime));
  }

  // Helper functions
  // TODO test that these are grabbing the right numbers
  _getLastDisconnect(instanceId) {
    const instances = this.getInstances();
    const instanceData = _.find(instances,
      (inst) => { return inst.id === instanceId });
    return instanceData && instanceData.lastDisconnect;
  }

  _getLastIdle(instanceId) {
    const instances = this.getInstances();
    const instanceData = _.find(instances,
      (inst) => { return inst.id === instanceId });
    return instanceData && instanceData.lastIdle;
  }
}

// Helper functions for constructing database updates;
// These are currently a bit janky.
function addResetDisconnectedUpdateFields(obj, discDurationMillis) {
  if (obj.$inc == null) {
    obj.$inc = {};
  }
  if (obj.$unset == null) {
    obj.$unset = {};
  }
  obj.$inc["instances.$.disconnectedTime"] = discDurationMillis;
  obj.$unset["instances.$.lastDisconnect"] = null;
  return obj;
}

function addResetIdleUpdateFields(obj, idleDurationMillis) {
  if (obj.$inc == null) {
    obj.$inc = {};
  }
  if (obj.$unset == null) {
    obj.$unset = {};
  }
  obj.$inc["instances.$.idleTime"] = idleDurationMillis;
  obj.$unset["instances.$.lastIdle"] = null;
  return obj;
}

TurkServer.Assignment = Assignment;
