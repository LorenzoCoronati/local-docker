# Local-docker

**NEVER EVER EVER USE THESE `docker-compse*.yml` FILES IN PRODUCTION**.

This is a template for local development, mainly targeted for Drupal.

In short: Drupal's all PHP lives in `./drupal` -folder, and index.php -
the docroot - is in `./drupal/web/index.php` -folder. Composer, Drush
and Drupal console can be used within `php` -containers shell:

        # on host
        $ docker-compose exec php bash
        # inside php container get status of site in `web/sites/default`
        /var/www # drush status 

## Requirements

Your laptop should have
[Docker and Docker compose](https://docs.docker.com/compose/) as well
as [Docker-sync](https://docker-sync.readthedocs.io). If you have
[Homebrew](https://brew.sh/) installed do these steps on you host (in
any directory):

         $ brew install cask 
         $ brew cask install docker-edge
         $ gem install docker-sync
         

## What's in the package?

Behind scenes `local-docker` uses Docker. Recipe of what is launched is
in `docker-compose.yml` (or for the DEVELOPMENT server
`docker-comopose.dev-vm.yml`).

To overcome the known technical limitations (ie. nerve wrecking local
drupal site slowness) `docker-sync` is being used. It sets up
[intermediate containers and hides the OSX filesystem incompatibility](https://docker-sync.readthedocs.io/en/latest/advanced/how-it-works.html)
there. 

### Pros and cons

**Con** is that the initial sync after launching the local takes a bit
of time (up to a few minutes). Once that is done local is ... ready.
Files syncing between host and docker containers may take a few seconds,
but running `docker-sync logs -f` on a terminal will expose what and
when is being synced.

**Pros** No rotten local development environments ever again! At least
for the handful of years a head of you. The trick is local environment
is not **built** locally, but loaded from the Docker hub as-is (apart
for some minor *config* adjustments).

## Usage

Main usage is done using a `ld.sh `script: `./ld`. Executing the scrip
without no arguments gives you command list.

### Start using local-docker

Copy all of this repository on top of your current project. 

        db_dumps/
        docker/
        drupal/ # if you do not have it yet
        docker-compose*.yml
        docker-sync*.yml
        ld.sh 
        ld  # symlink to ld.sh

Open your favourite terminal, type `./ld` and hit \[ENTER]. If you get
an error, ensure `ld.sh` has execute permission:

        chmod 0744 ld.sh

#### Skeleton

If your project is not Skeleton based, delete `*.skeleton.yml` -files.
If you are applying Local docker on a Skeleton based project, replace
docker-sync.yml with dockers-sync.skeleton.yml and docker-compose.yml
with docker-compose.skeleton.yml.

### Daily usage

Execute `./ld` to see some options to control your local docker stack.
Behind the scenes script starts and stops files syncing and containers.

More importantly using it helps you to not delete database by mistake,
but executes (and restores) database backups in `db_dumps/` -folder,
keeping most recent as the restoreable dump. 

#### Start local

If containers are not pulles/built yet, this will do it for you. 

     ./ld up            # or  
     docker-sync start && docker-compose up -d

#### Stop local

Just pu to sleep:

    ./ld stop # or 
    docker-compose stop [; docker-sync clean]

or remove containers (with whatever they have inside them)

    ./ld down # or 
    docker-compose down; docker-sync clean

Note that files sync must be started in order to start other containers,
and it keeps 1-n pcs of containers running when it is started.

#### Watch filesync logs

It may be helpful to keep eye on files sync logs.
 
     docker-sync logs -f

#### Create a snapshot/backup of database

This is done automatically when you stop or destroy your containers.

    ./ld dump

#### Restore (old) db backup
 
 Put a file in `db_dumps/` -folder and create a symlink pointing to it:
 
    ln -s db_dumps/GZIPPED_MYSQLDUMP_FILE.sql.gz ./db_dumps/db-container-dump-LATEST.sql.gz
    ./ld restore


#### Composer, Drush, Drupal

Composer, Drush or Drupal console are aliased inside `php` container. Do
your thing:

       $ docker-compose exec php bash
       /var/www # drush status
       /var/www # composer require drupal/pathauto:^1

Another way is run one-off commands in `php` -container:

       $ docker-compose exec php bash -c "drush status"

#### Compile CSS

Look at the `nodejs` -container in `docker-compose*.yml`, correct file
paths and enable it. Launch the project again to get the container
booted up.

You can expose nodejs container logs with:

      $ docker-compose logs -f nodejs

#### Xdbug

**Better instructions coming soon!**

Xdebug is installed and enabled by default. You should be able to
connect your IDE to container's IP address, port 9000.

To turn xdebug off add

     xdebug.remote_enable=0

to the bottom of file
`docker/build/php/7.2/conf.d/95-drupal-development.ini` (check your PHP
version from `docker-compose.yml`, default is `7.2`). After the change
you need to rebuild the `php` -container:

     ./ld rebuild

### Launch a new project

`./ld init` creates a drupal-project for you out-of-the-box (this will
take a few minutes). If you already have a `drupal/composer.json` file
you should not do that, but rather execute composer install:

       $ docker-compose exec php bash -c "composer install"

## Projects in paralled?

Docker volumes are using volume names from `docker-composer.yml` (see
root-level key `volumes`). If you collapse with other projects: 

1. stop file sync and local (`./ld down`) if needed
2. clean up your volumes `./ld nuke-volumes` if needed
3. rename all `webroot-sync-*` -named volumes in `docker-compose.yml` and
  `docker-sync.yml` -files
4. start your local again `./ld up` and optionally restore database
   `./ld restore`

## ISSUES 

#### Local files not getting synced

If you feel file sync is not working properly, start by checking logs
and editing some files that should be synced:

    $ docker-sync logs -f # -f flag keeps log tracker opened

If none of your edits in host or in container are being synced, clean up
and restart:

1. stop file sync and local (`./ld down`) if needed
2. clean up your volumes `./ld nuke-volumes` if needed
3. start your local again `./ld up` and optionally restore database
   `./ld restore`

**If this did not solve the sync** you can wipe out all volumes in your
system.

**BE WARNED** This will delete ALL volumes in ALL Docker projects across
your laptop.
 
        docker system prune --volumes
        
If even that does not help, clean up EVERYTHING Docker -related
(downloaded images, created volumes and containers).

**BE WARNED** This will delete ALL volumes, downloaded images and
containers in ALL Docker projects across your whole laptop. Sorts of
resets everything else but Docker configuration.

        docker system prune


## Why my favourite feature is not there?

This is the initial version of the local-docker. Redis, Solr and others
are coming once the need arises.

**Asking help from your colleagues is very recommended, and pull
requests even more so!**

