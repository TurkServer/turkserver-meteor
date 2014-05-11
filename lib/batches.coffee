class TurkServer.Batch
  _batches = {}

  @getBatch: (batchId) ->
    if (batch = _batches[batchId])?
      return batch
    else
      throw new Error("Batch does not exist") unless Batches.findOne(batchId)?
      return _batches[batchId] = new _Batch(batchId)

  @currentBatch: ->
    return unless (userId = Meteor.userId())?
    return TurkServer.Assignment.getCurrentUserAssignment(userId).getBatch()

class _Batch
  constructor: (@batchId) ->
    @lobby = new TurkServer.Lobby(@batchId)

  createInstance: (treatmentNames, fields) ->
    fields = _.extend fields || {},
      startTime: Date.now()
      batchId: @batchId
      treatments: treatmentNames || []

    groupId = Experiments.insert(fields)
    return new TurkServer.Instance(groupId)

  getTreatments: -> Batches.findOne(@batchId).treatments

  setAssigner: (assigner) ->
    throw new Error("Assigner already set for this batch") if @assigner?
    @assigner = assigner
    assigner.initialize(this)

TurkServer.ensureTreatmentExists = (props) ->
  throw new Meteor.Error(403, "Treatment must have a name") unless props.name?
  Treatments.upsert {name: props.name},
    $set: _.omit(props, "name")
