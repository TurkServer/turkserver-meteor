import * as os from "os";
import merge from "deepmerge";

// Client-side default settings, for reference
const defaultPublicSettings = {
  autoLobby: true,
  dataRoute: "/"
};

// Default server settings if not read in
const defaultSettings = {
  adminPassword: undefined,
  hits: {
    acceptUnknownHits: false
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

export const config = merge(defaultSettings, inputSettings || {});
