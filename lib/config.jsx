const os = Npm.require('os');
const merge = Npm.require('deepmerge');

// Client-side default settings, for reference
const defaultPublicSettings = {
  autoLobby: true,
  dataRoute: "/"
};

// Default server settings if not read in
const defaultSettings = {
  adminPassword: undefined,
  hits: {
    acceptUnknownHits: true
  },
  experiment: {
    limit: {
      simultaneous: 1,
      batch: 1
    }
  },
  mturk: {
    sandbox: true,
    accessKeyId: undefined,
    secretAccessKey: undefined,
    externalUrl: "https://" + os.hostname(),
    frameHeight: 900
  }
};

// Read and merge settings on startup
let inputSettings = Meteor.settings && Meteor.settings.turkserver;
TurkServer.config = merge(defaultSettings, inputSettings || {});
