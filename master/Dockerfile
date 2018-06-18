FROM  buildbot/buildbot-master:v1.2.0

RUN pip install requests && \
    pip install buildbot-grid-view==v1.2.0

COPY master.cfg /var/lib/buildbot
