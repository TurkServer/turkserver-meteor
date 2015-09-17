turkserver-meteor [![Build Status](https://travis-ci.org/HarvardEconCS/turkserver-meteor.svg)](https://travis-ci.org/HarvardEconCS/turkserver-meteor)
=================

TurkServer is a package for building interactive web-based user experiments on the [Meteor](http://www.meteor.com/) web app framework. It uses Meteor's powerful publish/subscribe data model and reactivity to make designing experimental 
interfaces easy while providing many automatic facilities for deploying your app and collecting data.

The Meteor version of TurkServer was based on the [original Java-based TurkServer](https://github.com/HarvardEconCS/TurkServer). However, it's much more powerful and easier to use.

## Features

- Design interfaces using the power and flexibility of Meteor.
- Multi-user, interactive experiments are as easy to build as single-user experiments.
- Highly configurable randomization of treatments.
- Deploying experiments from a live web interface and watch the progress of experiments in real time.

## Quick Start

1. [Install Meteor](http://docs.meteor.com/#quickstart) and create a Meteor app.
2. In the app directory, install TurkServer locally (once we publish TurkServer to the Meteor packaging server, you will be able to omit this step):

    ```
    git clone --recursive https://github.com/HarvardEconCS/turkserver-meteor.git packages/mizzao:turkserver
    ```

5. `meteor add mizzao:turkserver` to install the package and its dependencies.
6. Start your app with the `meteor` command.
7. Navigate to `/turkserver` to log into the administration interface, and develop your experiment!
8. Check out the **[tutorial](http://ldworkin.github.io/turkserver-tutorial)** and **[API documentation](https://turkserver
.meteor.com)** to get an idea of what you can use in your app. TurkServer extensively uses Meteor goodies such as real-time data and reactive variables, making apps easy to build.    

## Examples

TurkServer is currently still in development, but we have an in-depth 
[tutorial](http://ldworkin.github.io/turkserver-tutorial/) available with an 
accompanying [example app](https://github.com/ldworkin/turkserver-tutorial).  

We've also designed some very interesting studies using Turkserver. 
Publications are forthcoming: 

- https://github.com/mizzao/CrowdMapper studies collaboration and 
coordination in teams of varying size on a realistic task.
- https://github.com/ldworkin/meteor-prisoners-dilemma is a prisoners' 
dilemma experiment conducted daily over a *month*, with an order of magnitude
 more data than past studies. 

More examples and documentation will be coming soon.

## Research

If you use TurkServer in your work and publish a paper, please cite

> Andrew Mao, Yiling Chen, Krzysztof Z. Gajos, David Parkes, Ariel D. Procaccia, and Haoqi Zhang. TurkServer: Enabling Synchronous and Longitudinal Online Experiments. In the Fourth Workshop on Human Computation (HCOMP 2012). 

Note that this paper doesn't refer to the latest version of the system, but it
 is the same core idea. We plan to publish an improved paper detailing the 
 methods behind TurkServer in the near future. 

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
