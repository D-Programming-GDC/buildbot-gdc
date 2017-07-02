FROM buildbot/buildbot-worker:v0.9.9.post1

ENV DOCKER_GCC_VERSION 5

# The target that the worker will build for.
ARG TARGET

# Switch USER back to root to install common packages.
USER root

# Target specific dependencies.
COPY install-target-deps.sh /buildbot
RUN bash install-target-deps.sh $TARGET

COPY buildci.sh /buildbot

USER buildbot
