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

1. Install Meteor: `curl https://install.meteor.com | /bin/sh`
2. Create a Meteor app: `meteor create my_experiment`
3. `cd my_experiment`
4. Install TurkServer: `git clone --recursive https://github.com/HarvardEconCS/turkserver-meteor.git packages/turkserver`. (Soon, you will be able to do this with Meteor's packaging system.)
5. `mrt update turkserver` to install dependent packages with [Meteorite](https://github.com/oortcloud/meteorite).
6. `meteor` to start your app.
7. Navigate to `/turkserver` to log into the administration interface, and develop your experiment!

For more information, check out the **[documentation](https://turkserver.meteor.com)**.

## Examples

**NOTE:** TurkServer is currently still in development, but for those who are itching to try it out, feel free to reference any of the examples below (in increasing order of complexity.) See https://github.com/HarvardEconCS/turkserver-meteor/issues/3 for more info.

- https://github.com/kcarnold/hello-turkserver
- https://github.com/alicexigao/wisdomOfCrowds
- https://github.com/mizzao/CrowdMapper

