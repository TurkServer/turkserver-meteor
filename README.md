turkserver-meteor
=================

Implementation of the [TurkServer](https://github.com/HarvardEconCS/TurkServer) functionality as a plugin for the mind-blowing [Meteor](http://www.meteor.com/) web app framework, allowing any Meteor app to be run on MTurk. The point? Online experiments just became 10x easier to create.

## Usage

TBD when development is closer to completion.

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
