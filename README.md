turkserver-meteor
=================

Implementation of the [TurkServer](https://github.com/HarvardEconCS/TurkServer) functionality as a plugin for the mind-blowing [Meteor](http://www.meteor.com/) web app framework, allowing Meteor apps to be easily modified for MTurk experiments. Using this, will make your online experiments much easier to create and manage.

**NOTE:** TurkServer is currently still in development, but for those who are itching to try it out, feel free to reference any of the examples below (in increasing order of complexity.) See https://github.com/HarvardEconCS/turkserver-meteor/issues/3 for more info.

- https://github.com/kcarnold/hello-turkserver
- https://github.com/alicexigao/wisdomOfCrowds
- https://github.com/mizzao/CrowdMapper

## Usage

turkserver-meteor is a [smart package](https://atmosphere.meteor.com/) for your Meteor app, that is designed to sit on top of the main interface for your experiment and manage it.

Start by developing your application as a standalone Meteor app for a single instance of your experiment. Add TurkServer to your application as a smart package. You'll be able to do this with [Meteorite](https://github.com/oortcloud/meteorite) once development is closer to a public release.

Once added, you can navigate to `/turkserver` to log into the administration interface.

### Setting up collections

It's easy to use TurkServer because it takes full advantage of Meteor's powerful publish-subscribe data framework.

`TurkServer.registerCollection` tells makes a collection scope to each instance of an experiment.

### Initializing a treatment

`TurkServer.initialize` registers a callback handler when an experiment is created. All collection operations inside this handler will be scoped to the experiment.

**It's important to ensure that you do not do any yielding operations inside this handler.**

### The Lobby

TurkServer provides a lobby for grouping users into synchronous experiments.

### Tutorial and Quiz

TurkServer allows you to administer tutorials and quizzes for your participants to ensure understanding.

### Exit Surveys

Use an exit survey to collect final data and debrief participants.

## Settings

Put a structure like the following in `Meteor.settings` of your app.

```js
"turkserver": {
    "adminPassword": "something",
    "hits": {
        "acceptUnknownHits": true
    },
    "mturk": {
        "accessKeyId": "Your_AWS_Access_Key",
        "secretAccessKey": "Your_AWS_Secret_Key"
    }
}
```

Details are explained below.

- `adminPassword`: The password you will use to log in to the web interface.

### `hits`

- `acceptUnknownHits`: `true`/`false` whether to accept unrecognized HITs (those not created or forgotten) by the server for tasks. Needed for testing and generally safe, but leaves open the possibility of malicious behavior.

### `mturk`

- `accessKey`: Your AWS Access Key ID.
- `secretKey`: Your AWS Secret Access Key.

## Caveats

Because TurkServer runs alongside your app on both the server and client, strange behavior can occur when writing code without thoughtfulness. While we've tried our best to prevent easily-avoidable problems, some issues might still arise due to these reasons. These are some things to be aware of:

- **CSS conflicts**. TurkServer uses regular Bootstrap classes with no modification. If you use CSS classes that conflict with Bootstrap in your app, or selectors for unqualified tags, the admin backend will likely be messed up.
- **Meteor template name conflicts**. TurkServer templates all have the prefix `ts`.
- **Handlebars helper conflicts**. Internal TurkServer global helpers have the prefix `_ts`.
