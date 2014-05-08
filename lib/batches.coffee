class TurkServer.Batch
  batches = {}

  @getBatch: (batchId) ->
    if (batch = batches[batchId])?
      return batch
    else
      throw new Error("Batch does not exist") unless Batches.findOne(batchId)?
      return new TurkServer.Batch(batchId)

  @currentBatch: ->
    return unless (userId = Meteor.userId())?
    return TurkServer.Assignment.getCurrentUserAssignment(userId).getBatch()

  constructor: (@batchId) ->
    batches[@batchId] = this
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

