// TODO: move this to mizzao:user-status
interface UserStatus {
  online: boolean;
  idle: boolean;
}

interface UserTurkServerState {
  state: "exitsurvey";
}

// Define TurkServer-specific user data.
declare module "meteor/meteor" {
  module Meteor {
    interface User {
      admin: boolean;
      turkserver: UserTurkServerState;
      workerId: string;
      status: UserStatus;
    }
  }
}
