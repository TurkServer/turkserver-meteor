@TestUtils = {}

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

  # Get a wrapper that runs a before and after function wrapping some test function.
  TestUtils.getCleanupWrapper = (settings) ->
    before = settings.before
    after = settings.after
    # Take a function...
    return (fn) ->
      # Return a function that, when called, executes the hooks around the function.
      return ->
        before?()
        try
          fn.apply(this, arguments)
        catch error
          throw error
        finally
          after?()
