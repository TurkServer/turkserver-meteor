import { Meteor } from "meteor/meteor";
import { check } from "meteor/check";

import { Experiments, Treatments } from "../lib/shared";
import { TurkServer } from "../lib/common";
import { Assignment } from "./assignment";
import { Batch } from "./batches";

const init_queue = [];

/*
  XXX Note that the collection called "Experiments" now actually refers to instances
 */

// map of groupId to instance objects
// XXX Can't use WeakMap here because we have primitive keys
const _instances = new Map();

/**
 * @summary Represents a group or slice on the server, containing some users.
 * These functions are available only on the server. This object is
 * automatically constructed from TurkServer.Instance.getInstance.
 * @class
 * @instancename instance
 */
export class Instance {
  groupId: string;

  /**
   * @summary Get the instance by its id.
   * @param {String} groupId
   * @returns {TurkServer.Instance} the instance, if it exists
   */
  static getInstance(groupId) {
    check(groupId, String);

    let inst = _instances.get(groupId);
    if (inst != null) return inst;

    if (Experiments.findOne(groupId) == null) {
      throw new Error(`Instance does not exist: ${groupId}`);
    }

    // A fiber may have created this at the same time; if so use that one
    if ((inst = _instances.get(groupId) && inst != null)) return inst;

    inst = new Instance(groupId);
    _instances.set(groupId, inst);
    return inst;
  }

  /**
   * @summary Get the currently scoped instance
   * @returns {TurkServer.Instance} the instance, if it exists
   */
  static currentInstance() {
    const groupId = Partitioner.group();
    return groupId && this.getInstance(groupId);
  }

  /**
   * @summary Schedules a new handler to be called when an instance is initialized.
   * @param {Function} handler
   */
  static initialize(handler) {
    init_queue.push(handler);
  }

  constructor(groupId) {
    if (_instances.get(groupId)) {
      throw new Error("Instance already exists; use getInstance");
    }

    this.groupId = groupId;
  }

  /**
   * @summary Run a function scoped to this instance with a given context. The
   * value of context.instance will be set to this instance.
   * @param {Function} func The function to execute.
   * @param {Object} context Optional context to pass to the function.
   */
  bindOperation(func, context: any = {}) {
    context.instance = this;
    Partitioner.bindGroup(this.groupId, func.bind(context));
  }

  /**
   * @summary Run the initialization handlers for this instance
   */
  setup() {
    // Can't use fat arrow here.
    this.bindOperation(function() {
      TurkServer.log({
        _meta: "initialized",
        treatmentData: this.instance.treatment()
      });

      for (var handler of init_queue) {
        handler.call(this);
      }
    });
  }

  /**
   * @summary Add an assignment (connected user) to this instance.
   * @param {TurkServer.Assignment} asst The user assignment to add.
   */
  addAssignment(asst) {
    check(asst, Assignment);

    if (this.isEnded()) {
      throw new Error("Cannot add a user to an instance that has ended.");
    }

    // Add a user to this instance
    Partitioner.setUserGroup(asst.userId, this.groupId);

    Experiments.update(this.groupId, {
      $addToSet: {
        users: asst.userId
      }
    });

    Meteor.users.update(asst.userId, {
      $set: {
        "turkserver.state": "experiment"
      }
    });

    // Set experiment start time if this was first person to join
    Experiments.update(
      {
        _id: this.groupId,
        startTime: null
      },
      {
        $set: {
          startTime: new Date()
        }
      }
    );

    // Record instance Id in Assignment
    asst._joinInstance(this.groupId);
  }

  /**
   * @summary Get the users that are part of this instance.
   * @returns {Array} the list of userIds
   */
  users() {
    return Experiments.findOne(this.groupId).users || [];
  }

  /**
   * @summary Get the batch that this instance is part of.
   * @returns {TurkServer.Batch} the batch
   */
  batch() {
    const instance = Experiments.findOne(this.groupId);
    return instance && Batch.getBatch(instance.batchId);
  }

  /**
   * @summary Retrieve the names of treatments that were added to this instance.
   * @returns {String[]} Array of Treatment names.
   */
  getTreatmentNames() {
    const instance = Experiments.findOne(this.groupId);

    return (instance && instance.treatments) || [];
  }

  /**
   * @summary Get the treatment parameters for this instance.
   * @returns {Object} The treatment parameters.
   */
  treatment() {
    const instance = Experiments.findOne(this.groupId);

    return (
      instance &&
      TurkServer._mergeTreatments(
        Treatments.find({
          name: {
            $in: instance.treatments
          }
        })
      )
    );
  }

  /**
   * @summary How long this experiment has been running, in milliseconds
   * @returns {Number} Milliseconds that the experiment has been running.
   */
  getDuration() {
    const instance = Experiments.findOne(this.groupId);
    return (instance.endTime || new Date()) - instance.startTime;
  }

  /**
   * @summary Whether the instance is ended. If an instance is ended, it has a
   * recorded endTime and can't accept new users.
   * @returns {Boolean} Whether the experiment is ended
   */
  isEnded() {
    const instance = Experiments.findOne(this.groupId);
    return instance && instance.endTime != null;
  }

  /**
   * @summary Close this instance, optionally returning people to the lobby
   * @param {Boolean} returnToLobby Whether to return users to lobby after
   * teardown. Defaults to true.
   */
  teardown(returnToLobby = true) {
    // Set the same end time for all logs
    const now = new Date();

    Partitioner.bindGroup(this.groupId, function() {
      return TurkServer.log({
        _meta: "teardown",
        _timestamp: now
      });
    });

    Experiments.update(this.groupId, {
      $set: {
        endTime: now
      }
    });

    // Sometimes we may want to allow users to continue to access partition data
    if (!returnToLobby) return;

    const users = Experiments.findOne(this.groupId).users;
    if (users == null) return;

    for (let userId of users) {
      this.sendUserToLobby(userId);
    }
  }

  /**
   * @summary Send a user that is part of this instance back to the lobby.
   * @param {String} userId The user to return to the lobby.
   */
  sendUserToLobby(userId) {
    Partitioner.clearUserGroup(userId);
    let asst = Assignment.getCurrentUserAssignment(userId);
    if (asst == null) return;

    // If the user is still assigned, do final accounting and put them in lobby
    asst._leaveInstance(this.groupId);

    // TODO: an offline user should not be returned to the lobby
    this.batch().lobby.addAssignment(asst);
  }
}

TurkServer.Instance = Instance;

// XXX back-compat
TurkServer.initialize = Instance.initialize;
