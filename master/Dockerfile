FROM  buildbot/buildbot-master:v1.1.1

RUN pip install requests && \
    pip install buildbot-grid-view==v1.1.1

COPY master.cfg /var/lib/buildbot
