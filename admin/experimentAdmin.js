/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS103: Rewrite code to no longer use __guard__
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const treatments = () => Treatments.find();

Template.tsAdminExperiments.events({
  "submit form.-ts-admin-experiment-filter"(e, t) {
    e.preventDefault();

    return Router.go("tsExperiments", {
      days: parseInt(t.find("input[name=filter_days]").value) ||
        TurkServer.adminSettings.defaultDaysThreshold,
      limit: parseInt(t.find("input[name=filter_limit]").value) ||
        TurkServer.adminSettings.defaultLimit
    }
    );
  },

  "click .-ts-stop-experiment"() {
    const expId = this._id;
    return bootbox.confirm("This will end the experiment immediately. Are you sure?", function(res) {
      if (res) { return Meteor.call("ts-admin-stop-experiment", expId); }
    });
  }
});

Template.tsAdminExperiments.helpers({
  numExperiments() { return Experiments.find().count(); }});

const numUsers = function() { return (this.users != null ? this.users.length : undefined); };

Template.tsAdminExperimentMaintenance.events({
  "click .-ts-stop-all-experiments"(e) {
    return bootbox.confirm("This will end all experiments in progress. Are you sure?", function(res) {
      if (!res) { return; }
      return TurkServer.callWithModal("ts-admin-stop-all-experiments", Session.get("_tsViewingBatchId"));
    });
  }
});

Template.tsAdminExperimentTimeline.helpers({
  experiments() {
    return Experiments.find({startTime: {$exists: true}}, {
      sort: {startTime: 1},
      fields: {startTime: 1, endTime: 1}
    });
  }
});

Template.tsAdminExperimentTimeline.rendered = function() {
  this.lastUpdate = new ReactiveVar(new Date);

  const svg = d3.select(this.find("svg"));
  const $svg = this.$("svg");

  const margin =
    {bottom: 30};

  const chartHeight = $svg.height() - margin.bottom;

  const x = d3.scale.linear()
    .range([0, $svg.width()]);

  const y = d3.scale.ordinal()
    .rangeBands([0, $svg.height() - margin.bottom], 0.2);

  const xAxis = d3.svg.axis()
    .scale(x)
    .orient("bottom")
    .ticks(5) // Dates are long
    .tickFormat( date => new Date(date).toLocaleString());

  const svgX = svg.select("g.x.axis")
    .attr("transform", `translate(0,${chartHeight})`);

  const svgXgrid = svg.select("g.x.grid");

  const chart = svg.select("g.chart");

  const redraw = function() {
    // Update x axis
    svgX.call(xAxis);

    // Update x grid
    const grid = svgXgrid.selectAll("line.grid")
      .data(x.ticks(10)); // More gridlines than above

    grid.enter()
      .append("line")
      .attr("class", "grid");

    grid.exit().remove();

    grid.attr({
      x1: x,
      x2: x,
      y1: 0,
      y2: chartHeight
    });

    const now = Tracker.nonreactive(() => new Date(TimeSync.serverTime()));

    // Update bar positions; need to guard against missing values upon load
    return chart.selectAll(".bar").attr({
      x(e) { return (e && x(e.startTime)) || 0; },
      width(e) {
        return (e && Math.max( x(e.endTime || now) - x(e.startTime), 0 )) || 0;
      },
      y(e) { return (e && y(e._id)) || 0; },
      height: y.rangeBand()
    });
  };

  const zoom = d3.behavior.zoom()
    .scaleExtent([1, 100])
    .on("zoom", redraw);

  svg.call(zoom);

  return this.autorun(() => {
    this.lastUpdate.get();

    // Grab bound data
    const exps = chart.selectAll(".bar").data();

    // Note that this will redraw until experiments are done.
    // But, once all experiments are done, timesync won't be used

    // guards below since some bars may not have data bound
    // compute new domains
    const minStart = d3.min(exps, e => e != null ? e.startTime : undefined) || TimeSync.serverTime(null, 2000);
    // a running experiment hasn't ended yet :)
    const maxEnd = d3.max(exps, e => (e != null ? e.endTime : undefined) || TimeSync.serverTime(null, 2000));

    // However, we cannot use Deps.currentComputation.firstRun here as data may not
    // be ready on first run.
    x.domain( [minStart, maxEnd] );
    y.domain( exps.map( e => e && e._id) );

    // Set zoom **after** x axis has been initialized
    zoom.x(x);

    return redraw();
  });
};

Template.tsAdminExperimentTimeline.events({
  "click .bar"(e, t) {
    return TurkServer.showInstanceModal(this._id);
  }
});

Template.tsAdminExperimentTimelineBar.onRendered(function() {
  d3.select(this.firstNode).datum(this.data);
  // Trigger re-draw on parent, guard against first render
  return __guard__(this.parent().lastUpdate, x => x.set(new Date));
});

Template.tsAdminActiveExperiments.helpers({
  experiments() {
    return Experiments.find(
      {endTime: {$exists: false}}
    ,
      {sort: { startTime: -1 }});
  },

  numUsers
});

Template.tsAdminCompletedExperiments.helpers({
  experiments() {
    return Experiments.find(
      {endTime: {$exists: true}}
    ,
      {sort: { startTime: -1 }});
  },
  duration() {
    return TurkServer.Util.duration(this.endTime - this.startTime);
  },
  numUsers
});

Template.tsAdminExpButtons.helpers({
  dataRoute: __guard__(__guard__(Meteor.settings != null ? Meteor.settings.public : undefined, x1 => x1.turkserver), x => x.dataRoute)});

Template.tsAdminLogs.helpers({
  experiment() { return Experiments.findOne(this.instance); },
  logEntries() { return Logs.find({}, {sort: {_timestamp: -1}}); },
  entryData() { return _.omit(this, "_id", "_userId", "_groupId", "_timestamp"); }
});

Template.tsAdminLogs.events({
  "submit form.ts-admin-log-filter"(e, t) {
    e.preventDefault();
    const count = parseInt(t.find("input[name=count]").value);
    if (!count) { return; }

    return Router.go("tsLogs", {
      groupId: this.instance,
      count
    }
    );
  }
});

Template.tsAdminTreatments.helpers({
  treatments,
  zeroTreatments() { return Treatments.find().count() === 0; }
});

Template.tsAdminTreatments.events = {
  "click tbody > tr"(e) {
    return Session.set("_tsSelectedTreatmentId", this._id);
  },

  "click .-ts-delete-treatment"() {
    return Meteor.call("ts-delete-treatment", this._id, function(err, res) {
      if (err) { return bootbox.alert(err.message); }
    });
  }
};

Template.tsAdminNewTreatment.events = {
  "submit form"(e, tmpl) {
    e.preventDefault();
    const el = tmpl.find("input[name=name]");
    const name = el.value;
    el.value = "";

    if (!name) {
      bootbox.alert("Enter a non-empty string.");
      return;
    }

    return Treatments.insert(
      {name}
    , function(e) { if (e) { return bootbox.alert(e.message); } });
  }
};

Template.tsAdminTreatmentConfig.helpers({
  selectedTreatment() {
    return Treatments.findOne(Session.get("_tsSelectedTreatmentId"));
  }
});

Template.tsAdminConfigureBatch.events = {
  "click .-ts-activate-batch"() {
    return Batches.update(this._id, { $set: {
      active: true
    }
  }
    );
  },

  "click .-ts-deactivate-batch"() {
    return Batches.update(this._id, { $set: {
      active: false
    }
  }
    );
  },

  "change input[name=allowReturns]"(e) {
    return Batches.update(this._id, { $set: {
      allowReturns: e.target.checked
    }
  }
    );
  }
};

Template.tsAdminConfigureBatch.helpers({
  selectedBatch() { return Batches.findOne(Session.get("_tsSelectedBatchId")); }});

Template.tsAdminBatchEditDesc.rendered = function() {
  const container = this.$('div.editable');
  const grabValue = () => $.trim(container.text()); // Always get reactively updated value
  container.editable({
    value: grabValue,
    display() {}, // Never set text; have Meteor update to preserve reactivity
    success: (response, newValue) => {
      Batches.update(this.data._id,
        {$set: { desc: newValue }});
      // Thinks it knows the value, but it actually doesn't - grab a fresh value each time
      Meteor.defer(() => container.data('editableContainer').formOptions.value = grabValue);
    }
  }); // The value of this function matters
};

Template.tsAdminBatchEditTreatments.events = {
  "click .-ts-remove-batch-treatment"(e, tmpl) {
    const treatmentName = "" + (this.name || this); // In case the treatment is gone
    return Batches.update(Session.get("_tsSelectedBatchId"),
      {$pull: { treatments:  treatmentName }});
  },

  "click .-ts-add-batch-treatment"(e, tmpl) {
    e.preventDefault();
    const treatment = Blaze.getData(tmpl.find(":selected"));
    if (treatment == null) { return; }
    return Batches.update(this._id,
      {$addToSet: { treatments: treatment.name }});
  }
};

Template.tsAdminBatchEditTreatments.helpers({
  allTreatments: treatments});

Template.tsAdminBatchList.events = {
  "click tbody > tr"(e) {
    return Session.set("_tsSelectedBatchId", this._id);
  }
};

Template.tsAdminBatchList.helpers({
  batches() { return Batches.find(); },
  zeroBatches() { return Batches.find().count() === 0; },
  selectedClass() {
    if (Session.equals("_tsSelectedBatchId", this._id)) { return "info"; } else { return ""; }
  }
});

Template.tsAdminAddBatch.events = {
  "submit form"(e, tmpl) {
    e.preventDefault();

    const el = tmpl.find("input");
    const name = el.value;
    if (name === "") { return; }

    el.value = "";

    // Default batch settings
    return Batches.insert({
      name,
      grouping: "groupSize",
      groupVal: 1,
      lobby: true
    }
    , function(e) { if (e) { return bootbox.alert(e.message); } });
  }
};

function __guard__(value, transform) {
  return (typeof value !== 'undefined' && value !== null) ? transform(value) : undefined;
}