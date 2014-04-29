@TestUtils = {}

if Meteor.isClient
  # Prevent router from complaining about missing path
  Router.map ->
    @route "/",
      onBeforeAction: (pause) -> pause()

if Meteor.isServer
  # Set up a dummy batch
  unless Batches.findOne(active: true)
    Batches.insert(active: true)

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

