# AppBuilder api-sails image. Intended to be used in a stack with MariaDB,
# redis, and others.
#
# At build time the image will have root:root as the configured DB credentials.
# The runtime DB password must be mounted in a plaintext file located
# at "/secret/password".
#
# The Sails OpsPortal only works correctly in a node.js version 6 environment.
# But other aspects of the build, such as using webpack to compile the client
# side code, require a more modern version of node.js. Therefore, this image
# is built in 3 stages.
#  - STAGE1: node:6.12.3 for OpsPortal installation
#  - STAGE2: node:10 for client side code compilation
#  - STAGE3: node:6.12.3 for running Sails


FROM node:6.12.3 AS stage1
EXPOSE 1337/tcp
ENV NODE_ENV=production
USER root
RUN apt update
RUN echo 'mysql-server mysql-server/root_password password root' | debconf-set-selections
RUN echo 'mysql-server mysql-server/root_password_again password root' | debconf-set-selections
RUN apt install -y expect mysql-client mysql-server

RUN npm install -g sails@0.12.14
RUN npm install -g appdevdesigns/appdev-cli
ADD 01-CreateDBs.sql /root/
ADD install-op.exp /root/

# OpsPortal requires a working DB connection in order to install.
# We run mysqld in the same command as the OpsPortal installer, otherwise the 
# daemon process may get terminated before OpsPortal is done.

# Install OpsPortal
# (scripted run of `appdev install ab --develop`)
RUN nohup bash -c "mysqld &" && \
    sleep 2 && \
    mysql -uroot -proot -h 127.0.0.1 < /root/01-CreateDBs.sql && \
    expect -f /root/install-op.exp

# Clean up
RUN apt remove -y mysql-client mysql-server expect

WORKDIR /app
ADD reSetup.js /app/
RUN npm install --save skipper

# Remove obsolete OpsPortal modules
RUN rm -rf node_modules/opstool-hris* && \
    rm -f views/opstool-hris* && \
    rm -f api/controllers/opstool-hris* \
    rm -f api/models/API*.js && \
    rm -f api/policies/canHRIS.js && \
    head -n -2 config/routes.js > head.tmp && \
    mv head.tmp config/routes.js && \
    head -n -2 config/bootstrap.js > head.tmp && \
    mv head.tmp config/bootstrap.js && \
    head -n -2 config/policies.js > head.tmp && \
    mv head.tmp config/policies.js && \
    head -n -2 config/connections.js > head.tmp && \
    mv head.tmp config/connections.js

# Install AppBuilder module
ARG APPBUILDER_VER=1
WORKDIR /app
RUN npm install --save appdevdesigns/app_builder#jc/trim-dependencies
RUN npm install babel-preset-env@1.7.0

# Install opstool-emailNotifications
# (using normal `npm install` results in broken symlinks somehow)
WORKDIR /app/node_modules
RUN git clone https://github.com/appdevdesigns/opstool-emailNotifications opstool-emailNotifications
WORKDIR /app/node_modules/opstool-emailNotifications
RUN git checkout develop
RUN node setup/setup.js
RUN npm install


#######################################
# Switch to node.js v10 for webpack
FROM node:10 AS stage2
ENV NODE_ENV=production
COPY --from=stage1 /app /app

# Build AB client side code
WORKDIR /app
RUN node reSetup.js
WORKDIR /app/node_modules/app_builder
RUN npm install --only=dev
RUN npm run build

# Installing sails under node:10 to replace the symlink
RUN rm -rf node_modules/sails
RUN npm install sails@0.12.14

# Workaround for Steal.js minify error
WORKDIR /app/assets/OpsPortal
RUN sed s/'minify: true'/'minify: false'/g build.appdev.js > sed.tmp
RUN mv sed.tmp build.appdev.js

# Build OP client side code
RUN npm install -g appdevdesigns/appdev-cli
WORKDIR /app/assets
RUN appdev build OpsPortal


#######################################
# Switch back to node.js v6 for runtime launch
FROM stage1 AS stage3
COPY --from=stage2 /app /app

# Add default Sails route
COPY routes.js /app/config/
COPY PageController.js /app/api/controllers/
ADD opsportal.ejs /app/views/page/

# Lift Sails with runtime DB credentials
WORKDIR /app
ADD ab-launcher.js /app/
CMD node --max-old-space-size=2048 --stack-size=2048 ab-launcher.js
