FROM  buildbot/buildbot-master:v0.9.9.post1

RUN pip install requests && \
    pip install buildbot-grid-view

COPY master.cfg /var/lib/buildbot
