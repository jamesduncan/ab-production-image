# AppBuilder core image. Intended to be used in a stack with MariaDB, redis,
# and some others stuff.
#
# At build time the image will have root:root as the configured DB credentials.
# The runtime DB password must be mounted in a plaintext file located
# at "/secret/password".

FROM node:6.12.3
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
RUN nohup bash -c "mysqld &" && \
    sleep 2 && \
    mysql -uroot -proot -h 127.0.0.1 < /root/01-CreateDBs.sql && \
    expect -f /root/install-op.exp

WORKDIR /app
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
WORKDIR /app
RUN npm install --save appdevdesigns/app_builder#jc/trim-dependencies

# Install opstool-emailNotifications
# (using normal npm install results in broken symlinks somehow)
WORKDIR /app/node_modules
RUN git clone https://github.com/appdevdesigns/opstool-emailNotifications opstool-emailNotifications
WORKDIR /app/node_modules/opstool-emailNotifications
RUN git checkout develop
RUN node setup/setup.js
RUN npm install

# Build client side code
ARG RESETUP_VER=1
ADD reSetup.js /app/
WORKDIR /app
RUN node reSetup.js
WORKDIR /app/assets
RUN appdev build OpsPortal

# Clean up
RUN apt remove -y mysql-client mysql-server expect

# Add default Sails route
ARG ROUTES_VER=1
COPY routes.js /app/config/
COPY PageController.js /app/api/controllers/
ADD opsportal.ejs /app/views/page/

# Lift Sails with runtime DB credentials
WORKDIR /app
ARG AB_LAUNCHER_VER=1
ADD ab-launcher.js /app/
CMD node --max-old-space-size=2048 --stack-size=2048 ab-launcher.js
