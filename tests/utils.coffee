if Meteor.isClient
  # Prevent router from complaining about missing path
  Router.map ->
    @route "/",
      onBeforeAction: (pause) -> pause()

if Meteor.isServer
  # Cleanup junk that may have been leftover from other tests
  Meteor.users.remove {}
  Batches.remove {}
  Experiments.remove {}
  Assignments.remove {}
  Treatments.remove {}

  # Stub out the mturk API
  TestUtils.mturkAPI = {
    handler: null
  }

  TurkServer.mturk = (op, params) ->
    TestUtils.mturkAPI.op = op
    TestUtils.mturkAPI.params = params
    return TestUtils.mturkAPI.handler?(op, params)

# Get a wrapper that runs a before and after function wrapping some test function.
TestUtils.getCleanupWrapper = (settings) ->
  before = settings.before
  after = settings.after
  # Take a function...
  return (fn) ->
    # Return a function that, when called, executes the hooks around the function.
    return ->
      next = arguments[1]
      before?()

      unless next?
        # Synchronous version - Tinytest.add
        try
          fn.apply(this, arguments)
        catch error
          throw error
        finally
          after?()
      else
        # Asynchronous version - Tinytest.addAsync
        hookedNext = ->
          after?()
          next()
        fn.call this, arguments[0], hookedNext

TestUtils.sleep = Meteor._wrapAsync((time, cb) -> Meteor.setTimeout (-> cb undefined), time)

TestUtils.blockingCall = Meteor._wrapAsync(Meteor.call)
