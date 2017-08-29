turkserver-meteor [![Build Status](https://travis-ci.org/TurkServer/turkserver-meteor.svg)](https://travis-ci.org/TurkServer/turkserver-meteor)
=================

TurkServer is a package for building interactive web-based user experiments on
the [Meteor](https://www.meteor.com/) web app framework. It uses Meteor's
powerful publish/subscribe data model and reactivity to make building 
real-time user interfaces less error-prone, and provides facilities for 
deploying your app and collecting data.

## Features

- Design interfaces using the power and flexibility of Meteor.
- Multi-user, interactive experiments are as easy to build as single-user experiments.
- Highly configurable randomization of treatments.
- Deploying experiments from a live web interface and watch the progress of experiments in real time.

Here's an example of how TurkServer was used to run a [month-long prisoner's dilemma experiment][longrunpd]:

[longrunpd]: https://github.com/TurkServer/long-run-cooperation
  
[ ![TurkServer][ts-img] ][ts-link]

[ts-img]: https://j.gifs.com/2R4A4v.gif
[ts-link]: https://www.youtube.com/watch?v=qgS0T979uMQ

## Getting Started

See the [guide](http://turkserver.readthedocs.io/), which has information about 
getting started, system architecture, experiment design, and examples.
 
To add this to a Meteor app, follow these instructions: 

1. [Install Meteor](http://docs.meteor.com/#quickstart) and create a Meteor app.
3. `meteor add mizzao:turkserver` to install the package and its dependencies.
4. Start your app with the `meteor` command.
5. Navigate to `/turkserver` to log into the administration interface, and 
develop your experiment!

## Documentation

See the **[API documentation](http://turkserver.meteorapp.com)** to get an idea
of what you can use in your app.

This documentation is generated directly from [JSDoc](http://usejsdoc.org/)
comments in the code. To build the documentation locally, make sure you have
[`meteor-jsdoc`](https://www.npmjs.com/package/meteor-jsdoc) installed:

```
npm install -g meteor-jsdoc
```

Then build and view the docs with the following commands:

```
meteor-jsdoc build
meteor-jsdoc start
```

The documentation will be visible as a Meteor app on the specified port (default 3333).

## Research

If you use TurkServer in your work and publish a paper, please cite

> Andrew Mao, Yiling Chen, Krzysztof Z. Gajos, David Parkes, Ariel D. Procaccia, and Haoqi Zhang. TurkServer: Enabling Synchronous and Longitudinal Online Experiments. In the Fourth Workshop on Human Computation (HCOMP 2012). 

Note that this paper doesn't refer to the latest version of the system, but it
 is the same core idea. We plan to publish an improved paper detailing the 
 methods behind TurkServer in the near future. 

## Developing and Contributing

See [more information about contributing](Contributing.md).
