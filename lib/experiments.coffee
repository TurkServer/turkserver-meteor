init_queue = []

# The experiment-specific version of Meteor.startup
TurkServer.initialize = (handler) ->
  init_queue.push(handler)

# The global state that allows the initialize handler to be scoped
# Used in grouping.coffee
TurkServer._initGroupId = undefined

class TurkServer.Experiment
  @setup: (groupId, treatment) ->
    context =
      group: groupId
      treatment: treatment

    TurkServer._initGroupId = groupId

    # Catch any errors so that we can unset the groupId
    try
    # TODO address potential problems if one of these handlers yield
      _.each init_queue, (handler) -> handler.call(context)
    finally
      TurkServer._initGroupId = undefined

