var hashWithoutHash = function() {
  return location.hash.replace("#", "");
};

Session.setDefault("urlHash", hashWithoutHash());
$(window).on("hashchange", function () {
  Session.set("urlHash", hashWithoutHash());
});

Session.setDefault("showAllTypes", false);

Template.nav.events({
  "change .show-all-types input": function (event) {
    Session.set("showAllTypes", event.target.checked);
  }
});

Template.nav.helpers({
  current: function() {
    return Session.get("urlHash") === this.id ? "current" : "";
  },
  showPropertyTypes: function () {
    return Session.get("showAllTypes");
  },
});
