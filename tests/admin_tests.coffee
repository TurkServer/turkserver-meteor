batchId = "mturkBatch"
hitTypeId = "mturkHITType"

# Create dummy batch and HIT Type
Batches.upsert batchId, $set: {}

HITTypes.upsert {HITTypeId: hitTypeId},
  $set: { batchId }

# Temporarily disable the admin check during these tests
_checkAdmin = TurkServer.checkAdmin

withCleanup = TestUtils.getCleanupWrapper
  before: ->
    Batches.upsert batchId, $set:
      { active: false }
    TurkServer.checkAdmin = ->

  after: ->
    HITs.remove { HITTypeId: hitTypeId }
    TestUtils.mturkAPI.handler = null
    TurkServer.checkAdmin = _checkAdmin

Tinytest.add "admin - create HIT for active batch", withCleanup (test) ->

  newHitId = Random.id()
  TestUtils.mturkAPI.handler = (op, params) -> newHitId
  Batches.upsert batchId, $set: { active: true }

  # test
  Meteor.call "ts-admin-create-hit", hitTypeId, {}

  hit = HITs.findOne(HITId: newHitId)

  test.isTrue(hit)
  test.equal hit.HITId, newHitId
  test.equal hit.HITTypeId, hitTypeId

Tinytest.add "admin - create HIT for inactive batch", withCleanup (test) ->

  test.throws ->
    Meteor.call "ts-admin-create-hit", hitTypeId, {}
  , (e) -> e.error is 403

Tinytest.add "admin - extend HIT for active batch", withCleanup (test) ->

  HITId = Random.id()
  HITs.insert { HITId, HITTypeId: hitTypeId }
  Batches.upsert batchId, $set: { active: true }

  # Need to return something for GetHIT else massive complaining
  TestUtils.mturkAPI.handler = (op, params) ->
    switch op
      when "GetHIT" then {}

  Meteor.call "ts-admin-extend-hit", { HITId }

Tinytest.add "admin - extend HIT for inactive batch", withCleanup (test) ->

  HITId = Random.id()
  HITs.insert { HITId, HITTypeId: hitTypeId }

  test.throws ->
    Meteor.call "ts-admin-extend-hit", { HITId }
  (e) -> e.error is 403



