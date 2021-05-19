Base files for building the AppBuilder production [digiserve/ab-sails-api](https://hub.docker.com/repository/docker/digiserve/ab-sails-api) Docker image.


# Preface
Intended to be used in a stack with MariaDB, redis, and others. For the official
stack, please see https://github.com/appdevdesigns/ab-production-stack/

The goal is to build a full working image deterministically from the standard
tools and repositories. There should be no ambiguity about the origin of any
component.


# Requirements
At build time the image will have root:root as the configured DB credentials.
The runtime DB password must be mounted in a plaintext file located
at "/secret/password". The included `ab-launcher.js` will update the config
files accordingly before each launch.

A custom `local.js` config file may be mounted into the "/app/config/"
directory to change various settings. However, "/secret/password" still
supercedes that for the DB password, unless you bypass `ab-launcher.js`.


# Arguments
  - `AB_GITHUB_COMMIT`
  
    You may specify a branch, tag, or commit of the app_builder repository on github.
    The default is `master`.


# Example usage
`docker build --no-cache --compress --build-arg AB_GITHUB_COMMIT=f9f0715f -t digiserve/ab-sails-api:v1 .`
