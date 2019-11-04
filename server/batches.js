// TODO: This file was created by bulk-decaffeinate.
// Sanity-check the conversion and remove this comment.
/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS206: Consider reworking classes to avoid initClass
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
(function() {
  let _batches = undefined;
  const Cls = (TurkServer.Batch = class Batch {
    static initClass() {
      _batches = {};
    }

    static getBatch(batchId) {
      let batch;
      check(batchId, String);
      if ((batch = _batches[batchId]) != null) {
        return batch;
      } else {
        if (Batches.findOne(batchId) == null) { throw new Error("Batch does not exist"); }
        // Return this if another Fiber created it while we yielded
        return _batches[batchId] != null ? _batches[batchId] : (_batches[batchId] = new Batch(batchId));
      }
    }

    static getBatchByName(batchName) {
      check(batchName, String);
      const batch = Batches.findOne({name: batchName});
      if (!batch) { throw new Error("Batch does not exist"); }
      return this.getBatch(batch._id);
    }

    static currentBatch() {
      let userId;
      if ((userId = Meteor.userId()) == null) { return; }
      return TurkServer.Assignment.getCurrentUserAssignment(userId).getBatch();
    }

    constructor(batchId) {
      this.batchId = batchId;
      if (_batches[this.batchId] != null) { throw new Error("Batch already exists; use getBatch"); }
      this.lobby = new TurkServer.Lobby(this.batchId);
    }

    // Creating an instance does not set it up, or initialize the start time.
    createInstance(treatmentNames, fields) {
      fields = _.extend(fields || {}, {
        batchId: this.batchId,
        treatments: treatmentNames || []
      });

      const groupId = Experiments.insert(fields);

      // To prevent bugs if the instance is referenced before this returns, we
      // need to go through getInstance.
      const instance = TurkServer.Instance.getInstance(groupId);

      instance.bindOperation(() => TurkServer.log({
        _meta: "created"}));

      return instance;
    }

    getTreatments() { return Batches.findOne(this.batchId).treatments; }

    setAssigner(assigner) {
      if (this.assigner != null) { throw new Error("Assigner already set for this batch"); }
      this.assigner = assigner;
      return assigner.initialize(this);
    }
  });
  Cls.initClass();
  return Cls;
})();

TurkServer.ensureBatchExists = function(props) {
  if (props.name == null) { throw new Error("Batch must have a name"); }
  return Batches.upsert({name: props.name}, props);
};

TurkServer.ensureTreatmentExists = function(props) {
  if (props.name == null) { throw new Error("Treatment must have a name"); }
  return Treatments.upsert({name: props.name}, props);
};
