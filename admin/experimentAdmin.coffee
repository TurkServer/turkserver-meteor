treatments = -> Treatments.find()

Template.tsAdminExperiments.events
  "submit form.-ts-admin-experiment-filter": (e, t) ->
    e.preventDefault()

    Router.go "tsExperiments",
      days: t.find("input[name=filter_days]").valueAsNumber ||
        TurkServer.adminSettings.defaultDaysThreshold
      limit: t.find("input[name=filter_limit]").valueAsNumber ||
        TurkServer.adminSettings.defaultLimit

  "click .-ts-watch-experiment": ->
    groupId = @_id
    currentRoute = Router.current()
    # Go to new route to avoid triggering leaving group
    Router.go(Meteor.settings?.public?.turkserver?.watchRoute || "/")

    Meteor.call "ts-admin-join-group", groupId, (err, res) ->
      return unless err
      Router.go(currentRoute.path)
      bootbox.alert(err.reason)

  "click .-ts-stop-experiment": ->
    expId = @_id
    bootbox.confirm "This will end the experiment immediately. Are you sure?", (res) ->
      Meteor.call "ts-admin-stop-experiment", expId if res

Template.tsAdminExperiments.helpers
  numExperiments: -> Experiments.find().count()

numUsers = -> @users?.length

Template.tsAdminExperimentMaintenance.events
  "click .-ts-stop-all-experiments": (e) ->
    bootbox.confirm "This will end all experiments in progress. Are you sure?", (res) ->
      return unless res
      Meteor.call "ts-admin-stop-all-experiments", Session.get("_tsViewingBatchId"), (err, res) ->
        bootbox.alert(err) if err?
        bootbox.alert(res + " instances stopped") if res?

Template.tsAdminExperimentTimeline.helpers({
  experiments: ->
    Experiments.find({startTime: $exists: true}, {
      sort: {startTime: 1},
      fields: {startTime: 1, endTime: 1}
    })

})

Template.tsAdminExperimentTimeline.rendered = ->
  @lastUpdate = new ReactiveVar(new Date)

  svg = d3.select(this.find("svg"))
  $svg = this.$("svg")

  margin =
    bottom: 30

  chartHeight = $svg.height() - margin.bottom

  x = d3.scale.linear()
    .range([0, $svg.width()])

  y = d3.scale.ordinal()
    .rangeBands([0, $svg.height() - margin.bottom], 0.2)

  xAxis = d3.svg.axis()
    .scale(x)
    .orient("bottom")
    .ticks(5) # Dates are long
    .tickFormat( (date) -> new Date(date).toLocaleString() )

  svgX = svg.select("g.x.axis")
    .attr("transform", "translate(0,#{chartHeight})")

  svgXgrid = svg.select("g.x.grid")

  chart = svg.select("g.chart")

  redraw = ->
    # Update x axis
    svgX.call(xAxis)

    # Update x grid
    grid = svgXgrid.selectAll("line.grid")
      .data(x.ticks(10)) # More gridlines than above

    grid.enter()
      .append("line")
      .attr("class", "grid")

    grid.exit().remove()

    grid.attr
      x1: x
      x2: x
      y1: 0
      y2: chartHeight

    now = Tracker.nonreactive -> new Date(TimeSync.serverTime())

    # Update bar positions; need to guard against missing values upon load
    chart.selectAll(".bar").attr
      x: (e) -> x(e.startTime)
      width: (e) -> Math.max( x(e.endTime || now) - x(e.startTime), 0 )
      y: (e) -> y(e._id)
      height: y.rangeBand()

  zoom = d3.behavior.zoom()
    .scaleExtent([1, 100])
    .on("zoom", redraw)

  svg.call(zoom)

  this.autorun =>
    @lastUpdate.get()

    # Grab bound data
    exps = chart.selectAll(".bar").data()

    # Note that this will redraw until experiments are done.
    # But, once all experiments are done, timesync won't be used

    # guards below since some bars may not have data bound
    # compute new domains
    minStart = d3.min(exps, (e) -> e?.startTime) || TimeSync.serverTime(null, 2000)
    # a running experiment hasn't ended yet :)
    maxEnd = d3.max(exps, (e) -> e?.endTime || TimeSync.serverTime(null, 2000))

    # However, we cannot use Deps.currentComputation.firstRun here as data may not
    # be ready on first run.
    x.domain( [minStart, maxEnd] )
    y.domain( exps.map( (e) -> e._id ) )

    # Set zoom **after** x axis has been initialized
    zoom.x(x)

    redraw()

Template.tsAdminExperimentTimeline.events
  "click .bar": (e, t) ->
    TurkServer.showInstanceModal this._id

Template.tsAdminExperimentTimelineBar.onRendered ->
  d3.select(this.firstNode).datum(this.data)
  # Trigger re-draw on parent, guard against first render
  this.parent().lastUpdate?.set(new Date)

Template.tsAdminActiveExperiments.helpers
  experiments: ->
    Experiments.find
      endTime: {$exists: false}
    ,
      sort: { startTime: -1 }

  numUsers: numUsers

Template.tsAdminCompletedExperiments.helpers
  experiments: ->
    Experiments.find
      endTime: {$exists: true}
    ,
      sort: { startTime: -1 }
  duration: ->
    TurkServer.Util.duration(@endTime - @startTime)
  numUsers: numUsers

Template.tsAdminLogs.helpers
  experiment: -> Experiments.findOne(@instance)
  logEntries: -> Logs.find({}, {sort: _timestamp: -1})
  entryData: -> _.omit(@, "_id", "_userId", "_groupId", "_timestamp")

Template.tsAdminLogs.events
  "submit form.ts-admin-log-filter": (e, t) ->
    e.preventDefault()
    count = t.find("input[name=count]").valueAsNumber
    return unless count

    Router.go "tsLogs",
      groupId: @instance,
      count: count

Template.tsAdminTreatments.helpers
  treatments: treatments
  zeroTreatments: -> Treatments.find().count() is 0

Template.tsAdminTreatments.events =
  "click tbody > tr": (e) ->
    Session.set("_tsSelectedTreatmentId", @_id)

  "click .-ts-delete-treatment": ->
    Meteor.call "ts-delete-treatment", @_id, (err, res) ->
      bootbox.alert(err.message) if err

Template.tsAdminNewTreatment.events =
  "submit form": (e, tmpl) ->
    e.preventDefault()
    el = tmpl.find("input[name=name]")
    name = el.value
    el.value = ""

    unless name
      bootbox.alert "Enter a non-empty string."
      return

    Treatments.insert
      name: name
    , (e) -> bootbox.alert(e.message) if e

Template.tsAdminTreatmentConfig.helpers
  selectedTreatment: ->
    Treatments.findOne Session.get("_tsSelectedTreatmentId")

Template.tsAdminConfigureBatch.events =
  "click .-ts-activate-batch": ->
    Batches.update @_id, $set:
      active: true

  "click .-ts-deactivate-batch": ->
    Batches.update @_id, $set:
      active: false

  "change input[name=allowReturns]": (e) ->
    Batches.update @_id, $set:
      allowReturns: e.target.checked

Template.tsAdminConfigureBatch.helpers
  selectedBatch: -> Batches.findOne(Session.get("_tsSelectedBatchId"))

Template.tsAdminBatchEditDesc.rendered = ->
  container = @$('div.editable')
  grabValue = -> $.trim container.text() # Always get reactively updated value
  container.editable
    value: grabValue
    display: -> # Never set text; have Meteor update to preserve reactivity
    success: (response, newValue) =>
      Batches.update @data._id,
        $set: { desc: newValue }
      # Thinks it knows the value, but it actually doesn't - grab a fresh value each time
      Meteor.defer -> container.data('editableContainer').formOptions.value = grabValue
      return # The value of this function matters
  return

Template.tsAdminBatchEditTreatments.events =
  "click .-ts-remove-batch-treatment": (e, tmpl) ->
    treatmentName = "" + (@name || @) # In case the treatment is gone
    Batches.update Session.get("_tsSelectedBatchId"),
      $pull: { treatments:  treatmentName }

  "click .-ts-add-batch-treatment": (e, tmpl) ->
    e.preventDefault()
    treatment = Blaze.getData(tmpl.find(":selected"))
    return unless treatment?
    Batches.update @_id,
      $addToSet: { treatments: treatment.name }

Template.tsAdminBatchEditTreatments.helpers
  allTreatments: treatments

Template.tsAdminBatchList.events =
  "click tbody > tr": (e) ->
    Session.set("_tsSelectedBatchId", @_id)

Template.tsAdminBatchList.helpers
  batches: -> Batches.find()
  zeroBatches: -> Batches.find().count() is 0
  selectedClass: ->
    if Session.equals("_tsSelectedBatchId", @_id) then "info" else ""

Template.tsAdminAddBatch.events =
  "submit form": (e, tmpl) ->
    e.preventDefault()

    el = tmpl.find("input")
    name = el.value
    return if name is ""

    el.value = ""

    # Default batch settings
    Batches.insert
      name: name
      grouping: "groupSize"
      groupVal: 1
      lobby: true
    , (e) -> bootbox.alert(e.message) if e
