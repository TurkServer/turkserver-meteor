treatments = -> Treatments.find()

Template.tsAdminExperiments.events
  "click .-ts-watch-experiment": ->
    groupId = @_id
    currentRoute = Router.current()
    # Go to new route to avoid triggering leaving group
    Router.go(Meteor.settings?.public?.turkserver?.watchRoute || "/")

    Meteor.call "ts-admin-join-group", groupId, (err, res) ->
      return unless err
      Router.go(currentRoute)
      bootbox.alert(err.reason)

  "click .-ts-experiment-logs": ->
    groupId = @_id
    Router.go("/turkserver/logs/#{groupId}/100")

  "click .-ts-stop-experiment": ->
    expId = @_id
    bootbox.confirm "This will end the experiment immediately. Are you sure?", (res) ->
      Meteor.call "ts-admin-stop-experiment", expId if res

numUsers = -> @users?.length

Template.tsAdminExperimentMaintenance.events
  "click .-ts-stop-all-experiments": (e) ->
    bootbox.confirm "This will end all experiments in progress. Are you sure?", (res) ->
      return unless res
      Meteor.call "ts-admin-stop-all-experiments", Session.get("_tsViewingBatchId"), (err, res) ->
        bootbox.alert(err) if err?
        bootbox.alert(res + " instances stopped") if res?

Template.tsAdminExperimentTimeline.rendered = ->
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
    .tickFormat( (date) -> new Date(date).toLocaleTimeString() )

  svgX = svg.append("g")
    .attr("class", "x axis")
    .attr("transform", "translate(0,#{chartHeight})")

  svgXgrid = svg.append("g")
    .attr("class", "x grid")

  chart = svg.append("g")

  redraw = (bars) ->
    # Update x axis
    svgX.call(xAxis)

    # Update x grid
    grid = svgXgrid.selectAll("line.grid")
      .data(x.ticks(10))

    grid.enter()
      .append("line")
      .attr("class", "grid")

    grid.exit().remove()

    grid.attr
      x1: x
      x2: x
      y1: 0
      y2: chartHeight

    # Update bar positions
    bars ?= chart.selectAll(".bar")
    bars.attr
      x: (e) -> x(e.startTime)
      width: (e) -> x(e.endTime || maxEnd) - x(e.startTime)
      y: (e) -> y(e._id)
      height: y.rangeBand()

  this.autorun ->
    # TODO make a reactive array for this; massive performance increase :)
    exps = Experiments.find({}, {sort: {startTime: 1}}).fetch()

    # compute new domains
    maxEnd = d3.max(exps, (e) -> e.endTime)

    # Set domain on first render
    x.domain( [d3.min(exps, (e) -> e.startTime), maxEnd] ) if Deps.currentComputation.firstRun
    y.domain( _.map(exps, (e) -> e._id) )

    bars = chart.selectAll(".bar")
      .data(exps, (e) -> e._id )

    bars.enter()
      .append("rect")
      .attr("class", "bar")

    bars.exit().remove()

    redraw(bars)

  # Set zoom **after** x axis has been initialized
  zoom = d3.behavior.zoom()
  .x(x)
  .scaleExtent([1, 20])
  .on("zoom", redraw)

  svg.call(zoom)

Template.tsAdminActiveExperiments.experiments = ->
  Experiments.find
    endTime: {$exists: false}
  ,
    sort: { startTime: -1 }

Template.tsAdminActiveExperiments.numUsers = numUsers

Template.tsAdminCompletedExperiments.experiments = ->
  Experiments.find
    endTime: {$exists: true}
  ,
    sort: { startTime: -1 }

Template.tsAdminCompletedExperiments.duration = ->
  TurkServer.Util.duration(@endTime - @startTime)

Template.tsAdminCompletedExperiments.numUsers = numUsers

Template.tsAdminLogs.logEntries = -> Logs.find({}, {sort: _timestamp: -1})
Template.tsAdminLogs.entryData = -> _.omit(@, "_id", "_userId", "_groupId", "_timestamp")

Template.tsAdminTreatments.treatments = treatments
Template.tsAdminTreatments.zeroTreatments = -> Treatments.find().count() is 0

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

Template.tsAdminTreatmentConfig.selectedTreatment = ->
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

Template.tsAdminConfigureBatch.selectedBatch = ->
  Batches.findOne(Session.get("_tsSelectedBatchId"))

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
    treatment = UI.getElementData(tmpl.find(":selected"))
    return unless treatment?
    Batches.update @_id,
      $addToSet: { treatments: treatment.name }

Template.tsAdminBatchEditTreatments.allTreatments = treatments

Template.tsAdminBatchList.events =
  "click tbody > tr": (e) ->
    Session.set("_tsSelectedBatchId", @_id)

Template.tsAdminBatchList.batches = -> Batches.find()
Template.tsAdminBatchList.zeroBatches = -> Batches.find().count() is 0

Template.tsAdminBatchList.selectedClass = ->
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
