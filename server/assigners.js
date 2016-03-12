TurkServer.Assigners = {};

/**
 * @summary Top-level class that determines flow of users in and out of the
 * lobby. Overriding functions on this class controls how users are grouped
 * together.
 *
 * @class TurkServer.Assigner
 * @instancename assigner
 */
TurkServer.Assigner = class {

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
   * @param {@link TurkServer.Assignment[]} assts
   * @param {String[]} treatments
   * @returns The new {@link TurkServer.Instance} that was created.
   */
  assignToNewInstance(assts, treatments) {
    this.lobby.pluckUsers(_.pluck(assts, "userId"));

    const instance = this.batch.createInstance(treatments);
    instance.setup();
    for (let asst of assts) {
      instance.addAssignment(asst);
    }
    return instance;
  }

  /**
   * @summary Function that is called when a user enters the lobby, either from the initial entry or after returning from a world.
   * @param {@link TurkServer.Assignment} asst The user assignment (session) that just entered the lobby.
   */
  userJoined(asst) {

  }

  /**
   * @summary Function that is called when the status of a user in the lobby changes (such as the user changing from not ready to ready.)
   * @param {@link TurkServer.Assignment} asst The user assignment that changed status.
   * @param newStatus
   */
  userStatusChanged(asst, newStatus) {

  }

  /**
   * @summary Function that is called when a user disconnects from the lobby. This is only triggered by users losing connectivity, not from being assigned to a new instance).
   * @param {@link TurkServer.Assignment} asst The user assignment that departed.
   */
  userLeft(asst) {

  }
};

/**
 * Basic assigner that simulates a standalone app.
 * It puts everyone who joins into a single group.
 * Once the instance ends, puts users in exit survey.
 * @type {{}}
 */
TurkServer.Assigners.TestAssigner = class extends TurkServer.Assigner {

  initialize(batch) {
    super.initialize(batch);
    const exp = Experiments.findOne({batchId: this.batch.batchId});

    // Take any experiment from this batch, creating it if it doesn't exist
    if ( exp != null) {
      this.instance = TurkServer.Instance.getInstance(exp._id);
    } else {
      // TODO: refactor once batch treatments are separated from instance
      // treatments
      this.instance = this.batch.createInstance(this.batch.getTreatments());
      this.instance.setup();
    }
  }

  userJoined(asst) {
    if (asst.getInstances().length > 0) {
      this.lobby.pluckUsers([asst.userId]);
      asst.showExitSurvey();
    } else {
      this.instance.addAssignment(asst);
      this.lobby.pluckUsers([asst.userId]);
    }
  }

};

/**
 * Assigns everyone who joins in a separate group
 * Anyone who is done with their instance goes into the exit survey
 * @type {{}}
 */
TurkServer.Assigners.SimpleAssigner = class extends TurkServer.Assigner {

  userJoined(asst) {
   if (asst.getInstances().length > 0) {
     this.lobby.pluckUsers([asst.userId]);
     asst.showExitSurvey();
   } else {
     const treatments = this.batch.getTreatments() || [];
     this.assignToNewInstance([asst], treatments);
   }
  }

};

/************************************************************************
 * The assigners below are examples of different types of functionality.
 ************************************************************************/

/*
 Allows people to opt in after reaching a certain threshold.
 */
TurkServer.Assigners.ThresholdAssigner = class extends TurkServer.Assigner {
  constructor(groupSize) {
    super();
    this.groupSize = groupSize;
  }

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
};

/*
 Assigns users to groups in a randomized, round-robin fashion
 as soon as the join the lobby
 */
TurkServer.Assigners.RoundRobinAssigner = class extends TurkServer.Assigner {
  constructor(instanceIds) {
    super();
    this.instanceIds = instanceIds;

    // Create instances if they don't exist
    for( let instanceId of this.instanceIds ) {
      let instance;

      try {
        instance = TurkServer.Instance.getInstance(instanceId);
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
};

/*
 Assign users to fixed size experiments sequentially, as they arrive
 */
TurkServer.Assigners.SequentialAssigner = class extends TurkServer.Assigner {
  constructor(groupSize, instance) {
    super();
    this.groupSize = groupSize;
    this.instance = instance;
  }

  // Assignment for no lobby, fixed group size
  userJoined(asst) {
    if (this.instance.users().length >= this.groupSize) {
      // Create a new instance, replacing the one we are holding
      const treatment = _.sample(this.batch.getTreatments());
      this.instance = this.batch.createInstance([treatment]);
      this.instance.setup();
    }

    this.lobby.pluckUsers([asst.userId]);
    this.instance.addAssignment(asst);
  }

};
