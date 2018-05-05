FROM buildbot/buildbot-worker:v1.1.1

ENV DOCKER_GCC_VERSION 5

# The target that the worker will build for.
ARG TARGET

# Switch USER back to root to install common packages.
USER root

# Target specific dependencies.
COPY install-target-deps.sh /buildbot
RUN bash install-target-deps.sh $TARGET

COPY buildci.sh /buildbot

COPY baseboards/*.exp /usr/share/dejagnu/baseboards/
COPY config/*.exp /usr/share/dejagnu/config/
COPY scripts/*-run /usr/local/bin/

USER buildbot
