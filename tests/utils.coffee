
if Meteor.isClient
  # Prevent router from complaining about missing path
  Router.map ->
    @route "/",
      onBeforeAction: (pause) -> pause()

if Meteor.isServer
  # Set up a dummy batch
  unless Batches.find().count()
    Batches.insert(name: 'test')

  # Set up a dummy HIT type and HIT
  unless HITTypes.find().count()
    batch = Batches.findOne()
    hitTypeId = HITTypes.insert
      batchId: batch._id
    hitId = "authHitId"
    HITs.insert
      HITId: hitId
      HitTypeId: hitTypeId
