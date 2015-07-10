turkserver-meteor [![Build Status](https://travis-ci.org/HarvardEconCS/turkserver-meteor.svg)](https://travis-ci.org/HarvardEconCS/turkserver-meteor)
=================

TurkServer is a package for building interactive web-based user experiments on the [Meteor](http://www.meteor.com/) web app framework. It uses Meteor's powerful publish/subscribe data model and reactivity to make designing experimental interfaces a piece of cake while providing many automatic facilities for deploying your app and collecting data.

The Meteor version of TurkServer was based on the [original Java-based TurkServer](https://github.com/HarvardEconCS/TurkServer). However, it's much more powerful and easier to use.

## Features

- Design interfaces using the power of Meteor and just add TurkServer to get an experiment.
- Multi-user, interactive experiments are just as easy to build as single-user experiments.
- Highly configurable randomization of treatments and
- Graphical admin interface for deploying experiments on Amazon Mechanical Turk.
- Watch the progress of experiments in real time.
- Live log viewing of data generated in each experiment.

## Quick Start

The following are instructions for Meteor 0.9 or later:

1. [Install Meteor](http://docs.meteor.com/#quickstart) and create a Meteor app.
2. In the app directory, install TurkServer locally (once we publish TurkServer to the Meteor packaging server, you will be able to omit this step):

    ```
    git clone --recursive https://github.com/HarvardEconCS/turkserver-meteor.git packages/mizzao:turkserver
    ```

5. `meteor add mizzao:turkserver` to install the package and its dependencies.
6. Start your app with the `meteor` command.
7. Navigate to `/turkserver` to log into the administration interface, and develop your experiment!
8. Check out the **[documentation](https://turkserver.meteor.com)** to get an idea of what you can use in your app. TurkServer extensively uses Meteor goodies such as real-time data and reactive variables, making apps easy to build.
9. Deploy your experiment on free Meteor hosting and use real subjects on MTurk:

    ```
    meteor deploy my_experiment.meteor.com
    ```

## Examples

**NOTE:** TurkServer is currently still in development, but for those who are itching to try it out, feel free to reference https://github.com/mizzao/CrowdMapper as a full-fledged, working experiment.

See https://github.com/HarvardEconCS/turkserver-meteor/issues/3 for more info. More examples and documentation will be coming soon.

## Testing

Clone this entire repository, including the submodules. For example:

```
git clone --recursive https://github.com/HarvardEconCS/turkserver-meteor.git turkserver
```

Then run the tests:

```
cd turkserver
meteor test-packages ./
```

If you checked out the repository into an existing Meteor app, you can run `meteor test-packages turkserver` from your app instead.

Browse to `http://localhost:3000` to run the tests.

You don't have to run the tests yourself; this project is set up for continuous integration on [Travis CI](https://travis-ci.org/HarvardEconCS/turkserver-meteor), which runs these tests on each commit. 
