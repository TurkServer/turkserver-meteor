var apiData = function (options) {
  options = options || {};

  if (typeof options === "string") {
    options = {name: options};
  }

  var root = DocsData[options.name];

  if (! root) {
    console.log("API Data not found: " + options.name);
  }

  if (_.has(options, 'options')) {
    root = _.clone(root);
    var includedOptions = options.options.split(';');
    root.options = _.filter(root.options, function (option) {
      return _.contains(includedOptions, option.name);
    });
  }

  return root;
};

var changeNamesIfNeeded = function(nameList) {
  return _.map(nameList, function (name) {
    // decode the "Array.<Type>" syntax
    if (name.slice(0, 7) === "Array.<") {
      // get the part inside angle brackets like in Array<String>
      name = name.match(/<([^>]+)>/)[1];

      if (name) {
        return "Array of " + name + "s";
      }

      console.log("no array type defined");
      return "Array";
    }

    return name;
  });
};

var toOrSentence = function (array) {
  if (array.length === 1) {
    return array[0];
  } else if (array.length === 2) {
    return array.join(" or ");
  }

  return _.initial(array).join(", ") + ", or " + _.last(array);
};

var typeNames = function(nameList) {
  // change names if necessary
  nameList = changeNamesIfNeeded(nameList);
  nameList = _.flatten(nameList);

  return toOrSentence(nameList);
};

Template.autoApiBox.helpers({
  apiData: apiData,
  signature: function () {
    var signature;
    var escapedLongname = _.escape(this.longname);
    var params, paramNames;

    if (this.istemplate || this.ishelper) {
      if (this.istemplate) {
        signature = "{{> ";
      } else {
        signature = "{{ ";
      }

      signature += escapedLongname;

      params = this.params;

      paramNames = _.map(params, function (param) {
        var name = param.name;

        name = name + "=" + name;

        if (param.optional) {
          return "[" + name + "]";
        }

        return name;
      });

      signature += " " + paramNames.join(" ");

      signature += " }}";
    } else {
      var beforeParens;

      if (this.scope === "instance") {
        if (apiData(this.memberof)) {
          beforeParens = "<em>" + apiData(this.memberof).instancename + "</em>." + this.name;
        } else {
          beforeParens = escapedLongname;
        }
      } else if (this.kind === "class") {
        beforeParens = "new " + escapedLongname;
      } else {
        beforeParens = escapedLongname;
      }

      signature = beforeParens;

      // if it is a function, and therefore has arguments
      if (_.contains(["function", "class"], this.kind)) {
        params = this.params;

        paramNames = _.map(params, function (param) {
          if (param.optional) {
            return "[" + param.name + "]";
          }

          return param.name;
        });

        signature += "(" + paramNames.join(", ") + ")";
      }
    }

    return signature;
  },
  typeNames: function() {
    if (Session.get("showAllTypes") && this.type) {
      return typeNames(this.type.names);
    }

    return undefined;
  },
  id: function () {
    return this.longname.replace(/[.#]/g, "-");
  },
  paramsNoOptions: function () {
    return _.reject(this.params, function (param) {
      return param.name === "options";
    });
  }
});

Template.api_box_args.helpers({
  typeNames: function () {
    return typeNames(this.type.names);
  }
});

Template.api_box_eg.rendered = function () {
  hljs.configure({
    tabReplace: "  ",
    useBR: true,
    languages: ["javascript", "css", "json", "coffeescript"]
  });
  this.$("code").each(function(i, block) {
    hljs.highlightBlock(block);
  });
};
