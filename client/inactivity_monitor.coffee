class InactivityMonitor

  # TODO: catch window blur events where supported

  @intervalMonitorId = null

  constructor: (@callback, @threshold = 30000, @interval = 5000) ->

  start: ->
    # Cancel existing if necessary
    @stop()
    @reset()

    # Set new monitoring interval
    @intervalMonitorId = setInterval(@monitor, @interval) unless @intervalMonitorId

  stop: ->
    return unless @intervalMonitorId
    clearInterval(@intervalMonitorId)
    @intervalMonitorId = null

  reset: ->
    return unless @intervalMonitorId

    currentTime = Date.now()
    inactiveTime = currentTime - @lastInactive

    @callback?(inactiveTime) if inactiveTime > @inactivityThreshold

    @lastInactive = currentTime

  monitor: =>
    currentTime = Date.now()
    inactiveTime = currentTime - @lastInactive

    return unless inactiveTime > @inactivityThreshold

    # TODO Send inactivity to turkserver
#    @channelSend @userSubscription[0],
#      status: "inactive",
#      start: @lastInactive,
#      time: inactiveTime

    @callback?(inactiveTime)
