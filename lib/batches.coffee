batches = {}

TurkServer.getBatch = (batchId) ->
  if (batch = batches[batchId])?
    return batch
  else
    throw new Error("Batch does not exist") unless Batches.findOne(batchId)?
    return new TurkServer.Batch(batchId)

TurkServer.currentBatch = ->


class TurkServer.Batch
  constructor: (@batchId) ->
    batches[@batchId] = this
    @lobby = new TurkServer.Lobby(@batchId)

