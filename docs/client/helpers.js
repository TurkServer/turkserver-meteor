var pre = _.filter(_.keys(Template), function(name) {
  var char;
  char = name[0];
  return char !== "_" && char !== char.toLowerCase();
}).map(function(name) {
  return {
    id: name.toLowerCase().replace(/\ /g, ""),
    name: name
  }
});

// Preamble sections
Template.registerHelper("preamble", pre);

Template.registerHelper("sections", function() {
  var ret = [];
  var walk = function (items, depth) {
    _.each(items, function (item) {
      // Work around (eg) accidental trailing commas leading to spurious holes
      // in IE8.
      if (!item)
        return;
      if (item instanceof Array) {
        walk(item, depth + 1);
        if (depth === 2)
          ret.push({type: 'spacer', depth: 2});
      }
      else {
        if (typeof(item) === "string")
          item = {name: item};

        var id = item.name.replace(/[.#]/g, "-");

        ret.push(_.extend({
          type: "section",
          depth: depth,
          id: id,
        }, item));
      }
    });
  };

  var namespaces = _.groupBy(DocsNames, function(name) {
    return name.split('.')[0];
  });

  var toc = _.chain(namespaces).map(function(functions, namespace) {
    return [namespace, functions];
  }).flatten(true).value();

  walk(toc, 1);
  return ret;
});

Template.registerHelper("type", function(what) {
  return this.type === what;
});

Template.registerHelper("depthIs", function (n) {
  return this.depth === n;
});

Template._section.helpers({
  theTemplate: function() {
    return Template[this];
  }
});
