FROM  buildbot/buildbot-master:v0.9.13

RUN pip install requests && \
    pip install buildbot-grid-view==0.9.13

COPY master.cfg /var/lib/buildbot
