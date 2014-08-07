class TurkServer.Batch
  _batches = {}

  @getBatch: (batchId) ->
    check(batchId, String)
    if (batch = _batches[batchId])?
      return batch
    else
      throw new Error("Batch does not exist") unless Batches.findOne(batchId)?
      # Return this if another Fiber created it while we yielded
      return _batches[batchId] ?= new Batch(batchId)

  @currentBatch: ->
    return unless (userId = Meteor.userId())?
    return TurkServer.Assignment.getCurrentUserAssignment(userId).getBatch()

  constructor: (@batchId) ->
    throw new Error("Batch already exists; use getBatch") if _batches[@batchId]?
    @lobby = new TurkServer.Lobby(@batchId)

  createInstance: (treatmentNames, fields) ->
    fields = _.extend fields || {},
      startTime: new Date
      batchId: @batchId
      treatments: treatmentNames || []

    groupId = Experiments.insert(fields)

    Partitioner.bindGroup groupId, ->
      TurkServer.log
        _meta: "created"

    # To prevent bugs if the instance is referenced before this returns, we
    # need to go through getInstance.
    return TurkServer.Instance.getInstance(groupId)

  getTreatments: -> Batches.findOne(@batchId).treatments

  setAssigner: (assigner) ->
    throw new Error("Assigner already set for this batch") if @assigner?
    @assigner = assigner
    assigner.initialize(this)

TurkServer.ensureBatchExists = (props) ->
  throw new Error("Batch must have a name") unless props.name?
  Batches.upsert {name: props.name},
    $set: _.omit(props, "name")

TurkServer.ensureTreatmentExists = (props) ->
  throw new Error("Treatment must have a name") unless props.name?
  Treatments.upsert {name: props.name},
    $set: _.omit(props, "name")
