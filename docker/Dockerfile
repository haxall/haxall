# syntax=docker/dockerfile:1

################################################################################
# Running haxall requires fantom, haystack-defs, and xeto to be set up
# Either should I do this via docker compose? have multiple docker files run?
# probably not... since they would have to be downloaded before running this dockerfile
# so instead, I should actually just do all of it here in this file
# run the installation and stuff. 
# We will call this development mode, since I don't know what the
# difference is between dev and production mode. What needs to be included
# or excluded?

ARG JDK_VERSION=17
FROM eclipse-temurin:$JAVA_VER AS fantom


################################################################################
# Create a stage for building/compiling the application.
FROM fantom AS build
WORKDIR /.

# Copy over all files
COPY ./* .
WORKDIR /haxall

# haxall will be initiated with defaults from -headless argument. 
# its default database name will be "app"
# default username is "su" 
# password is randomly generated
# default port is 8082
ARG OPTIONS=-headless
ARG NAME=app
ENV APPNAME=${NAME}
RUN ./bin/hx version
RUN ./bin/hx init ${OPTIONS} ${NAME}

EXPOSE 8082

################################################################################
# Create a final stage for running your application.
# This makes smallest image size
FROM fantom AS haxall

# Copy the executable from the "build" stage.
COPY --from=build ./bin ./bin

# What the container should run when it is started.
CMD [ "./bin/hx", "run", "$APPNAME" ]
