# ab-production-image
Base files for building the AppBuilder production api-sails Docker image.


## Preface
Intended to be used in a stack with MariaDB, redis, and others.

The goal is to build a full working image deterministically from the standard
tools and repositories. There should be no ambiguity about the origin of any
component.


## Requirements
At build time the image will have root:root as the configured DB credentials.
The runtime DB password must be mounted in a plaintext file located
at "/secret/password". The included `ab-launcher.js` will update the config
files accordingly before each launch.


## Example usage
`docker build -t ab-production .`
