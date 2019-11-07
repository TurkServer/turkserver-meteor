import * as _ from "underscore";

import { Batch } from "./batches";
import { Lobby } from "./lobby_server";
import { Experiments } from "../lib/shared";
import { Instance } from "./instance";
import { Assignment } from "./assignment";

/**
 * @summary Top-level class that determines flow of users in and out of the
 * lobby. Overriding functions on this class controls how users are grouped
 * together.
 *
 * @class
 * @instancename assigner
 */
export abstract class Assigner {
  batch: Batch;
  lobby: Lobby;

  /**
   * @summary Initialize this assigner for a particular batch. This should set up the assigner's internal state, including reconstructing state after a server restart.
   * @param {String} batch The {@link TurkServer.Batch} object to initialize this assigner on.
   */
  initialize(batch) {
    this.batch = batch;
    this.lobby = batch.lobby;

    // Pre-bind callbacks below to avoid ugly fat arrows
    this.lobby.events.on("user-join", this.userJoined.bind(this));
    this.lobby.events.on("user-status", this.userStatusChanged.bind(this));
    this.lobby.events.on("user-leave", this.userLeft.bind(this));
  }

  /**
   * @summary Take a set of assignments from the lobby and create a new instance with the given treatments.
   * @param {Assignment[]} assts
   * @param {String[]} treatments
   * @returns The new {@link Instance} that was created.
   */
  assignToNewInstance(assts, treatments) {
    this.lobby.pluckUsers(_.pluck(assts, "userId"));

    const instance = this.batch.createInstance(treatments);
    for (let asst of assts) {
      instance.addAssignment(asst);
    }
    instance.setup();
    return instance;
  }

  /**
   * @summary Function that is called when a user enters the lobby, either from the initial entry or after returning from a world.
   * @param asst The user assignment {@link TurkServer.Assignment} (session) that just entered the lobby.
   */
  abstract userJoined(asst: Assignment);

  /**
   * @summary Function that is called when the status of a user in the lobby changes (such as the user changing from not ready to ready.)
   * @param asst The user assignment {@link TurkServer.Assignment} that
   * changed status.
   * @param newStatus
   */
  abstract userStatusChanged(asst: Assignment, newStatus: boolean);

  /**
   * @summary Function that is called when a user disconnects from the lobby. This is only triggered by users losing connectivity, not from being assigned to a new instance).
   * @param asst The user assignment {@link TurkServer.Assignment}  that departed.
   */
  abstract userLeft(asst: Assignment);
}

/**
 * @summary Basic assigner that simulates a standalone app.
 * It puts everyone who joins into a single group.
 * Once the instance ends, puts users in exit survey.
 * @class
 */
export class TestAssigner extends Assigner {
  instance: Instance;

  initialize(batch) {
    super.initialize(batch);
    const exp = Experiments.findOne({ batchId: this.batch.batchId });

    // Take any experiment from this batch, creating it if it doesn't exist
    if (exp != null) {
      this.instance = Instance.getInstance(exp._id);
    } else {
      // TODO: refactor once batch treatments are separated from instance
      // treatments
      this.instance = this.batch.createInstance(this.batch.getTreatments());
      this.instance.setup();
    }
  }

  userJoined(asst: Assignment) {
    if (asst.getInstances().length > 0) {
      this.lobby.pluckUsers([asst.userId]);
      asst.showExitSurvey();
    } else {
      this.instance.addAssignment(asst);
      this.lobby.pluckUsers([asst.userId]);
    }
  }

  userStatusChanged(asst: Assignment, newStatus: boolean) {}
  userLeft(asst: Assignment) {}
}

/**
 * @summary Assigns everyone who joins in a separate group
 * Anyone who is done with their instance goes into the exit survey
 * @class
 */
export class SimpleAssigner extends Assigner {
  userJoined(asst) {
    if (asst.getInstances().length > 0) {
      this.lobby.pluckUsers([asst.userId]);
      asst.showExitSurvey();
    } else {
      const treatments = this.batch.getTreatments() || [];
      this.assignToNewInstance([asst], treatments);
    }
  }

  userStatusChanged(asst: Assignment, newStatus: boolean): void {}
  userLeft(asst: Assignment): void {}
}

/************************************************************************
 * The assigners below are examples of different types of functionality.
 ************************************************************************/

/*
 Allows people to opt in after reaching a certain threshold.
 */
export class ThresholdAssigner extends Assigner {
  readonly groupSize: number;

  constructor(groupSize) {
    super();
    this.groupSize = groupSize;
  }

  userJoined(asst: Assignment) {}

  userStatusChanged() {
    const readyAssts = this.lobby.getAssignments({
      status: true
    });

    if (readyAssts.length < this.groupSize) return;

    // Default behavior is to assign a random treatment
    // We could improve this in the future
    const treatment = _.sample(this.batch.getTreatments());
    this.assignToNewInstance(readyAssts, [treatment]);
  }

  userLeft(asst: Assignment) {}
}

/*
 Assigns users to groups in a randomized, round-robin fashion
 as soon as the join the lobby
 */
export class RoundRobinAssigner extends Assigner {
  readonly instanceIds: string[];
  readonly instances: Instance[];

  constructor(instanceIds) {
    super();
    this.instanceIds = instanceIds;
    this.instances = [];

    // Create instances if they don't exist
    for (let instanceId of this.instanceIds) {
      let instance;

      try {
        instance = Instance.getInstance(instanceId);
      } catch (err) {
        // TODO pick treatments when creating instances
        instance = this.batch.createInstance();
      }

      this.instances.push(instance);
    }
  }

  userJoined(asst) {
    // By default, assign this to the instance with the least number of users
    const minUserInstance = _.min(this.instances, function(instance) {
      return instance.users().length;
    });
    this.lobby.pluckUsers([asst.userId]);
    minUserInstance.addAssignment(asst);
  }

  userStatusChanged(asst: Assignment, newStatus: boolean) {}
  userLeft(asst: Assignment) {}
}

/*
 Assign users to fixed size experiments sequentially, as they arrive
 */
export class SequentialAssigner extends Assigner {
  readonly groupSize: number;
  instance: Instance;

  constructor(groupSize, instance) {
    super();
    this.groupSize = groupSize;
    this.instance = instance;
  }

  // Assignment for no lobby, fixed group size
  userJoined(asst) {
    if (this.instance.users().length >= this.groupSize) {
      // Create a new instance, replacing the one we are holding
      const treatment: string = _.sample(this.batch.getTreatments());
      this.instance = this.batch.createInstance([treatment]);
      this.instance.setup();
    }

    this.lobby.pluckUsers([asst.userId]);
    this.instance.addAssignment(asst);
  }
  userStatusChanged(asst: Assignment, newStatus: boolean) {}
  userLeft(asst: Assignment) {}
}
