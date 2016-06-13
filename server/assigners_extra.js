/*
  This file contains more involved assigners used in actual experiments.
  You can see the app code at https://github.com/TurkServer
  DISCLAIMER: some of this code may not be the best way to implement the functionality shown.
 */

/**
 * Assigns users first to a tutorial treatment, then to a single group.
 * An event on the lobby is used to trigger the group.
 */
TurkServer.Assigners.TutorialGroupAssigner = class extends TurkServer.Assigner {

  constructor(tutorialTreatments, groupTreatments, autoAssign = false) {
    super();

    this.tutorialTreatments = tutorialTreatments;
    this.groupTreatments = groupTreatments;
    this.autoAssign = autoAssign;

    if (this.groupTreatments.length === 0) {
      // If empty, picking up an existing treatment won't work
      throw new Error("Group treatments must contain at least one element");
    }
  }

  initialize(batch) {
    super.initialize(batch);

    // if experiment was already created, and in progress store it
    const exp = Experiments.findOne({
      batchId: this.batch.batchId,
      treatments: { $all: this.groupTreatments },
      endTime: { $exists: false }
    }, {
      sort: { startTime: -1 }
    });

    if (exp != null) {
      this.instance = TurkServer.Instance.getInstance(exp._id);
      console.log("Auto-assigning to existing instance " + this.instance.groupId);
      this.autoAssign = true;
    }
    // If already initialized with autoAssign, create instance
    else if (this.autoAssign) {
      this.createInstance();
    }

    this.lobby.events.on("auto-assign", () => {
      this.autoAssign = true;
      this.assignAllUsers();
    });
  }

  createInstance() {
    this.instance = this.batch.createInstance(this.groupTreatments);
    this.instance.setup();
  }

  // put all users who have done the tutorial in the group
  assignAllUsers() {
    if (this.instance == null) {
      this.createInstance();
    }

    const assts = _.filter(this.lobby.getAssignments(), function(asst) {
      return asst.getInstances().length === 1;
    });

    for( let asst of assts )  {
      this.lobby.pluckUsers([asst.userId]);
      this.instance.addAssignment(asst);
    }
  }

  // Assign users to the tutorial, the group, and the exit survey
  userJoined(asst) {
    const instances = asst.getInstances();
    if (instances.length === 0) {
      this.assignToNewInstance([asst], this.tutorialTreatments);
    } else if (instances.length === 2) {
      this.lobby.pluckUsers([asst.userId]);
      asst.showExitSurvey();
    } else if (this.autoAssign) {
      // Put me in, coach!
      this.lobby.pluckUsers([asst.userId]);
      this.instance.addAssignment(asst);
    }

  }
};

function ensureGroupTreatments(sizeArray) {
  for (let size of _.uniq(sizeArray)) {
    TurkServer.ensureTreatmentExists({
      name: "group_" + size,
      groupSize: size
    });
  }
}

/*
 Assigner that puts people into a tutorial and then random groups, with

 - Pre-allocation of groups for costly operations before users arrive
 - A waiting room that can hold the first arriving users
 - Completely random assignment into different groups
 - Restarting and resuming assignment from where it left off
 - A final "buffer" group to accommodate stragglers after randomization is done

 This was created for executing the crisis mapping experiment.
 */
TurkServer.Assigners.TutorialRandomizedGroupAssigner =
  class TutorialRandomizedGroupAssigner extends TurkServer.Assigner {

    static generateConfig(sizeArray, otherTreatments) {
      ensureGroupTreatments(sizeArray);

      const config = [];

      for (let size of sizeArray) {
        config.push({
          size: size,
          treatments: ["group_" + size].concat(otherTreatments)
        });
      }

      // Create a buffer group for everyone else
      config.push({
        treatments: otherTreatments
      });

      return config;
    }

    constructor(tutorialTreatments, groupTreatments, groupArray) {
      super();
      this.tutorialTreatments = tutorialTreatments;
      this.groupTreatments = groupTreatments;
      this.groupArray = groupArray;
    }

    initialize(batch) {
      super.initialize(batch);

      this.configure();
      this.lobby.events.on("setup-instances", this.setup.bind(this));
      this.lobby.events.on("configure", this.configure.bind(this));
      this.lobby.events.on("auto-assign", this.assignAll.bind(this));
    }

    // If pre-allocated instances don't exist, create and initialize them
    setup(lookBackHours = 6) {
      console.log("Creating new set of instances for randomized groups");

      const existing = Experiments.find({
        batchId: this.batch.batchId,
        treatments: { $nin: this.tutorialTreatments },
        $or: [
          { startTime: { $gte: new Date(Date.now() - lookBackHours * 3600 * 1000) } },
          { startTime: null }
        ]
      }).fetch();

      // Reuse buffer instance if it already exists
      if (existing.length > 0 && _.any(existing, (exp) => exp.startTime != null )) {
        console.log("Not creating new instances as recently started ones already exist");
        return;
      }

      this.groupConfig = TutorialRandomizedGroupAssigner.generateConfig(this.groupArray, this.groupTreatments);

      if (existing.length === this.groupConfig.length) {
        console.log("Not creating new instances as we already have the expected number");
        return;
      }

      // Some existing instances exist. Count how many are available to reuse
      const reusable = {};

      for ( let exp of existing ) {
        let key;

        if (exp.treatments[0].indexOf("group_") >= 0) {
          key = parseInt(exp.treatments[0].substring(6));
        } else {
          key = "buffer";
        }
        console.log("Will reuse one existing instance with " + exp.treatments);

        if (exp.endTime != null) {
          Experiments.update(exp._id, {
            $unset: { endTime: null }
          });
          console.log("Reset an unused terminated instance: " + exp._id);
        }

        if (reusable[key] == null) { reusable[key] = 0; }
        reusable[key]++;
      }

      // create and setup instances
      for (let config of this.groupConfig ) {
        // Skip creating reusable instances
        let key = config.size || "buffer";
        if ((reusable[key] != null) && (reusable[key] > 0)) {
          console.log("Skipping creating one group of " + key);
          reusable[key]--;
          continue;
        }

        const instance = this.batch.createInstance(config.treatments);
        instance.setup();
      }

      // Configure randomization with these groups
      this.configure(undefined, lookBackHours);
    }

    // TODO remove the restriction that groupArray has to be passed in sorted
    configure(groupArray, lookBackHours = 6) {
      if (groupArray != null) {
        this.groupArray = groupArray;
        console.log("Configuring randomized group assigner with", this.groupArray);
      } else {
        console.log("Initialization of randomized group assigner with", this.groupArray);
      }

      this.groupConfig = TutorialRandomizedGroupAssigner.generateConfig(this.groupArray, this.groupTreatments);

      // Check if existing created instances exist
      const existing = Experiments.find({
        batchId: this.batch.batchId,
        treatments: { $nin: this.tutorialTreatments },
        $or: [
          { startTime: { $gte: new Date(Date.now() - lookBackHours * 3600 * 1000) } },
          { startTime: null }
        ]
      }, {
        transform: function(exp) {
          exp.treatmentData = TurkServer.Instance.getInstance(exp._id).treatment();
          return exp;
        }
      }).fetch();

      if (existing.length < this.groupConfig.length) {
        console.log("Not setting up randomization: " + existing.length + " existing groups");
        return;
      }

      // Sort existing experiments by smallest groups first for matching purposes.
      // The buffer group goes to the end.
      existing.sort(function(a, b) {
        if (a.treatmentData.groupSize == null) {
          // b comes first
          return 1;
        } else if (b.treatmentData.groupSize == null) {
          // a comes first
          return -1;
        } else {
          return a.treatmentData.groupSize - b.treatmentData.groupSize;
        }
      });

      const availableSlots = [];

      // Compute remaining slots on existing groups
      for( let exp of existing ) {
        const filled = exp.users && exp.users.length || 0;

        if (exp.treatmentData.groupSize == null) {
          console.log(`${exp._id} (buffer) has ${filled} users`);
          this.bufferInstanceId = exp._id;
          continue;
        }

        const target = exp.treatmentData.groupSize;
        // In case some bug overfilled it
        const remaining = Math.max(0, target - filled);

        console.log(`${exp._id} has ${remaining} slots left (${filled}/${target})`);

        for (let x = 0; x < remaining; x++) {
          availableSlots.push(exp._id);
        }

        if (filled > 0) {
          this.autoAssign = true;
        }
      }

      if (this.autoAssign) {
        console.log("Enabled auto-assign as instances currently have users");
      }

      this.instanceSlots = _.shuffle(availableSlots);
      this.instanceSlotIndex = 0;

      console.log(this.instanceSlots.length + " randomization slots remaining");
    }

    userJoined(asst) {
      const instances = asst.getInstances();
      if (instances.length === 0) {
        // This function automatically removes users from the lobby
        this.assignToNewInstance([asst], this.tutorialTreatments);
      } else if (instances.length === 2) {
        this.lobby.pluckUsers([asst.userId]);
        asst.showExitSurvey();
      } else if (this.autoAssign) {
        // Put me in, coach!
        this.assignNext(asst);
      }
      // Otherwise, wait for auto-assignment event
    }

    // Randomly assign all users in the lobby who have done the tutorial
    assignAll() {
      if (this.instanceSlots == null) {
        console.log("Can't auto-assign as we haven't been set up yet");
        return;
      }

      const currentAssignments = this.lobby.getAssignments();

      // Auto assign future users that join after this point
      // We can't put this before getting current assignments,
      // or some people might get double assigned, with
      // "already in a group" errors.
      // TODO this should be theoretically right after grabbing LobbyStatus but
      // before populating assignments.
      this.autoAssign = true;

      const assts = _.filter(currentAssignments, function(asst) {
        return asst.getInstances().length === 1;
      });

      for( let asst of assts ) {
        this.assignNext(asst);
      }
    }

    assignNext(asst) {
      if (this.instanceSlotIndex >= this.instanceSlots.length) {
        const bufferInstance = TurkServer.Instance.getInstance(this.bufferInstanceId);

        if (bufferInstance.isEnded()) {
          console.log("Not assigning " + asst.asstId + " as buffer has ended");
          return;
        }

        this.lobby.pluckUsers([asst.userId]);
        bufferInstance.addAssignment(asst);
        return;
      }

      const nextInstId = this.instanceSlots[this.instanceSlotIndex];
      this.instanceSlotIndex++;

      const instance = TurkServer.Instance.getInstance(nextInstId);

      if (instance.isEnded()) {
        console.log("Skipping assignment to slot for ended instance " + instance.groupId);
        // Recursively try to assign to the next slot
        this.assignNext(asst);
        return;
      }

      this.lobby.pluckUsers([asst.userId]);
      instance.addAssignment(asst);
    }
  };

/*
 Assign people to a tutorial treatment and then sequentially to different sized
 groups. Used for the crisis mapping experiment.

 groupArray = e.g. [ 16, 16 ]
 groupConfig = [ { size: x, treatments: [ stuff ] }, ... ]

 After the last group is filled, there is no more assignment.
 */
TurkServer.Assigners.TutorialMultiGroupAssigner = class TutorialMultiGroupAssigner extends TurkServer.Assigner {

  static generateConfig(sizeArray, otherTreatments) {
    ensureGroupTreatments(sizeArray);

    const config = [];

    for (let size of sizeArray) {
      config.push({
        size: size,
        treatments: ["group_" + size].concat(otherTreatments)
      });
    }

    return config;
  }

  constructor(tutorialTreatments, groupTreatments, groupArray) {
    super();
    this.tutorialTreatments = tutorialTreatments;
    this.groupTreatments = groupTreatments;
    this.groupArray = groupArray;
  }

  initialize(batch) {
    super.initialize(batch);

    this.configure();

    // Provide a quick way to re-set the assignment for multi-groups
    this.lobby.events.on("reset-multi-groups", () => {
      console.log("Resetting multi-group assigner with ", this.groupArray);
      this.stopped = false;
      this.currentInstance = null;
      this.currentGroup = -1;
      this.currentFilled = 0;
    });

    this.lobby.events.on("reconfigure-multi-groups", this.configure.bind(this));
  }

  configure(groupArray, lookBackHours = 6) {

    if (groupArray) {
      this.groupArray = groupArray;
      this.stopped = false;
      console.log("Reconfiguring multi-group assigner with", this.groupArray);
    } else {
      console.log("Initial setup of multi-group assigner with", this.groupArray);
    }

    this.groupConfig = TutorialMultiGroupAssigner.generateConfig(this.groupArray, this.groupTreatments);

    // If we resurrected in the middle of a server restart, pick up where we
    // left off.
    //
    // TODO it's a bit of a hack to look for the last 6 hours, but it seems to
    // be the only way to find a threshold where new experiments (1 day later)
    // won't pick up from previous ones and yet we give experiments in progress
    // enough time to finish if there are any problems.
    // TODO we need to make this support running multiple batches in a day.

    this.currentInstance = null;
    this.currentGroup = -1; // i.e. before the start of the array
    this.currentFilled = 0;

    const existing = Experiments.find({
      batchId: this.batch.batchId,
      treatments: { $nin: this.tutorialTreatments },
      startTime: { $gte: new Date(Date.now() - lookBackHours * 3600 * 1000) }
    }, {
      sort: { startTime: 1 }
    }).fetch();

    const results = [];

    for( let i = 0; i < existing.length; i++ ) {
      let exp = existing[i];
      let count = exp.users && exp.users.length || 0;
      let target = this.groupConfig[i].size;
      if (count === target) {
        console.log("Group of size " + target + " already filled in " + exp._id);
        this.currentGroup = i;
        this.currentFilled = count;
        results.push(this.currentInstance = TurkServer.Instance.getInstance(exp._id));
      } else if (count > target || i !== existing.length - 1 || !_.isEqual(exp.treatments, this.groupConfig[i].treatments)) {
        // Group sizes either don't match or this isn't the last one
        console.log("Unable to match with existing groups, starting over");
        this.currentInstance = null;
        this.currentGroup = -1;
        this.currentFilled = 0;
        break;
      } else {
        this.currentGroup = i;
        this.currentFilled = count;
        this.currentInstance = TurkServer.Instance.getInstance(exp._id);
        console.log("Initializing multi-group assigner to group " + this.currentGroup + " (" + this.currentFilled + "/" + target + ")");
        break; // We set the counter to the last assigned group.
      }
    }
    // TODO after reconfiguring, we may want to re-assign any users in the lobby.

    return results;
  }

  currentGroupFilled() {
    return this.currentFilled === this.groupConfig[this.currentGroup].size;
  }

  userJoined(asst) {
    // TODO if users join way after we assigned, it is probably time to start a new set. For now we accomplish that by restarting the server or hitting the reset above.
    const instances = asst.getInstances();
    if (instances.length === 0) {
      this.assignToNewInstance([asst], this.tutorialTreatments);
    } else if (instances.length === 2) {
      this.lobby.pluckUsers([asst.userId]);
      asst.showExitSurvey();
    } else {
      this.assignNext(asst);
    }
  }

  assignNext(asst) {
    // Don't assign if experiments are done
    if (this.stopped) return;

    // Check if the last group has already been stopped.
    if (this.currentGroup === this.groupConfig.length - 1 &&
      this.currentInstance .isEnded()) {
      this.stopped = true;
      console.log("Final group has finished, stopping automatic multi-group assignment");
      return;
    }

    if (this.currentGroup === this.groupConfig.length - 1 && this.currentGroupFilled()) {
      this.stopped = true;
      console.log("Final group has filled, stopping automatic multi-group assignment");
      return;
    }

    // It's imperative we do not do any yielding operations while updating counters
    if ((this.currentInstance == null) || this.currentGroupFilled()) {
      const newGroup = this.currentGroup + 1;

      const treatments = this.groupConfig[newGroup].treatments;
      this.currentInstance = this.safeCreateInstance(treatments);

      // Update group counters only once, if we are the first fiber to arrive here
      if (this.currentGroup === newGroup) {
        // New group already created. Try again on the next tick
        Meteor.defer(() => { this.assignNext(asst); });
        return;
      } else {
        // First to return from create instance. Put the user in this instance.
        this.currentGroup = newGroup;
        this.currentFilled = 0;
      }
    }

    this.currentFilled++;
    this.lobby.pluckUsers([asst.userId]);
    this.currentInstance.addAssignment(asst);
  }

  // Do not create multiple instances if multiple fibers arrive at a full
  // instance simultaneously
  //
  // Yes, this is necessary! During the experiment where we basically DDoSed
  // ourselves, we saw that the getInstance function was called before
  // createInstance returned, resulting in an error when we tried to create a new
  // TurkServer.Instance at the very end of it - a rare but hard to see bug that
  // is now fixed.
  safeCreateInstance(treatments) {
    if (this.creatingInstanceId != null) {
      return TurkServer.Instance.getInstance(this.creatingInstanceId);
    }
    this.creatingInstanceId = Random.id();

    // For idempotency, pick an _id before we create the instance
    const instance = this.batch.createInstance(treatments, {
      _id: this.creatingInstanceId
    });
    instance.setup();
    this.creatingInstanceId = null;

    return instance;
  }
};
