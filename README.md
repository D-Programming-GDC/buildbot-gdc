Setting up master:
----------------------------------
```
cd /srv/buildbot/
git clone https://github.com/D-Programming-GDC/buildbot-gdc.git .

cat > master/db.env << EOF
POSTGRES_DB=buildbot
POSTGRES_USER=buildbot
POSTGRES_PASSWORD=psqlpasswd  # Substitute password here.  Do not commit this.
POSTGRES_HOST=x.x.x.x         # Substitute address of database.
EOF

cat > common/secrets.env << EOF
# Secrets shared between master and workers.
WORKERPASS=password           # Substitute password here.  Do not commit this.
BUILDMASTER_CLIENT_ID=github_client_id          # Same.
BUILDMASTER_CLIENT_SECRET=github_client_secret  # Same.
EOF

docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d buildbot
```

Updating the master:
----------------------------------
```
cd /srv/buildbot/
docker-compose stop buildbot
git pull
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up --build -d buildbot
```


Adding a new worker (local):
----------------------------------
* docker-compose.yml:
  - Create a new service entry.
```
<service-name>:
  build:
    context: workers
    args:
      TARGET: <target configuration for worker>
  env_file:
    - common/common.env
    - common/secrets.env
  environment:
    WORKERNAME: <worker name>
  hostname: <worker host>
  domainname: <worker domain>
  volumes:
    - /srv/buildbot/cache:/buildbot/cache
  links:
    - buildbot
```

* workers/install-target-deps.sh:
  - Add switch case if this is a new TARGET that requires extra software packages
    other than native.

* master/master.cfg:
  - Add worker entries to the `builder_map` in master/master.cfg, one for each
    target that the worker is supposed to handle.  The format is: `'target-os-triplet': '<worker name>'`


Adding a new worker (remote):
----------------------------------
```
cd /srv/buildbot/
git clone https://github.com/D-Programming-GDC/buildbot-gdc.git .
```

Update files as per adding a new worker (local), except that in docker-compose.yml,
don't include `links: buildbot`.

Set-up a stunnel to the buildbot master, add host to service entry:
```
  extra_hosts:
    buildbot: x.x.x.x
```

Testing buildbot locally:
----------------------------------
Create all environment files as per setting up master, but use the testing configuration instead
to build the container.
```
docker-compose -f docker-compose.yml -f docker-compose.testing.yml up
```
