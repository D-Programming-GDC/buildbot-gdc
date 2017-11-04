FROM  buildbot/buildbot-master:v0.9.12.post1

RUN pip install requests && \
    pip install buildbot-grid-view==0.9.12.post1

COPY master.cfg /var/lib/buildbot
