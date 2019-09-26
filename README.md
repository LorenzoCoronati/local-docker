# Local-docker

**NEVER EVER EVER USE THESE `docker-compose*.yml` FILES IN PRODUCTION**.

This is a template for local development, mainly targeted for Drupal.

In short: Drupal's all PHP lives in `./app` -folder, and index.php - the
docroot - is in `./app/web/index.php` -folder. Composer, Drush and
Drupal console should be used within `php` -container:

    # on host
    $ docker-compose exec php bash
    # inside php container get status of site in `web/sites/default`
    /var/www # drush status 

## Requirements

Your laptop should have
[Docker and Docker compose](https://docs.docker.com/compose/) as well
as [Docker-sync](https://docker-sync.readthedocs.io). Install
[Homebrew](https://brew.sh/) if you have not done it already, and run
this on you host (in any directory):

    $ brew install cask 
    $ brew cask install docker-edge # edge channel OR
    $ brew cask install docker # stable channel
    $ sudo gem install docker-sync

You may have the Docker already installed, in which case
[Homebrew](https://brew.sh/) will tell you.

## What's in the package?

Behind scenes `local-docker` uses Docker. Recipe of what is launched is
in `docker-compose.yml` (or for the DEVELOPMENT server
`docker-compose.dev-vm.yml`).

To overcome the known technical limitations (ie. nerve wrecking local
drupal site slowness) `docker-sync` is being used. It sets up
[intermediate containers and hides the OSX filesystem incompatibility](https://docker-sync.readthedocs.io/en/latest/advanced/how-it-works.html)
there. 

### Pros and cons

**Con** is that the initial sync after launching the local takes a bit
of time (up to a few minutes). Once that is done local is ... ready.
Files syncing between host and docker containers may take a few seconds,
but running `docker-sync logs -f` on a terminal will expose what and
when is being synced. It is also the fastest tested flavor of various
ways to share folders between host and containers (including NFS
mounts).

**Pros** No rotten local development environments ever again! At least
for the handful of years a head of you. The trick is local environment
is not **built** locally, but loaded from the Docker hub as-is (apart
for some minor *config* adjustments).

## Usage

Main usage is done using a `ld.sh `script: `./ld`. Executing the script
without no arguments gives you command list.

### Start using local-docker

This tool can be used both as a base for new Drupal 8 projects and as a
local development tool for Skeleton based projects (known by Exove
developers).

#### New project
Clone this repository as your project folder, reconfigure Git repository
and start the initialisation.

    $ git clone git@github.com:Exove/local-docker.git my-project
    $ cd my-project
    # Reconfigure first git remote 'origin' (so you do not push to
    # local-docker -repository by mistake).
    $ git remote set-url origin ssh://git.example.com/my-project.git
    # Verify you have correct remote url's.
    $ git remote -v
    # Create a disconnected temporary branch w/ no commits. This new 
    # branch is not connected to the old repository branches.
    $ git checkout --orphan master-new
    # Commit clean project base to the new and still empty branch.
    $ git commit -am'Initial commit for my-project from local-docker'
    # Delete old master branch (with the full commit history), and
    # rename your temporary branch to master.
    $ git branch -D master
    $ git branch -m master-new master
    $ git push
    $ ./ld init

#### Existing project
 
Copy all of this repository on top of your current project.

    db_dumps/
    docker/
    .env.example 
    .gitignore.example # (or copy rules to your existing .gitignore)
    ld.sh 
    ld  # (ensure you have this symlinking to correct ld.sh)

Open your favourite terminal, type `./ld` and hit \[ENTER]. If you get
an error, ensure `ld.sh` has execute permission:

    $ chmod 0744 ld.sh

Initial setup asks if you some generic information. 

    $ ./ld init

If you are applying `local-docker` on a Skeleton -based project, see
"Skeleton" -section .

### Local domains

`./ld init` sets up your local IP addresses and domains. You'll be asked
for a local development domain among ohter things, and `local-docker`
will write a `/etc/hosts` -record for you and maintain localhost IP
address aliases.

#### Install Drupal

After setting your domains point your browser to the correct domain. If
all is well and Drupal is not yet installed you'll be redirected to
`mylocal.example.com/core/install.php`.

Install Drupal as usual. Be default database -container (`db`) has one
database (`drupal`) and credentials for accessing (`drupal`/`drupal`).
**Database hostname must be `db`** (database container name). Docker
connects containers internally using container names.

If you need more databases or need to manage anything inside Drupal's
database, you can
1) connect to `db` container either via shell

        $ docker-compose exec db sh

2. or use Adminer with your browser (port is configured in
   `docker-composer.yml`, see `adminer.ports`):
   [http://mylocal.example.com:8080](http://mylocal.example.com:8080)

3. or use your favourite SQL GUI app (SequelPro or similar), and connect
   using IP (host) `0.0.0.0`, default port `3306`, username `root` and
   password from your `.env`-file, `MYSQL_ROOT_PASSWORD`.
 
#### Skeleton

If you are applying Local-docker on a Skeleton based project start by
copying all things mentioned in "Start using local-docker" -section on
top of your project repository. 

    $ ./ld init skeleton

After some configuration your codebase is built, and Docker volumes
(including volumes used by `docker-sync`) according general Skeleton
structure.

Drupal should also connect to correct database host. This is usually
done via your site's `settings.php` -file. Where Skeleton may use
`localhost` as the database host. `local-docker` uses `db` container,
and by default credentials `drupal`/`drupal` with database named
`drupal` (simple!). Example for Drupal 8:

    <?php 
      $databases['default']['default'] = [
        'database' => 'drupal',
        'username' => 'drupal',
        'password' => 'drupal',
        'prefix' => '',
        'host' => 'db',   // <== IMPORTANT!
        'port' => '3306',
        'namespace' => 'Drupal\\Core\\Database\\Driver\\mysql',
        'driver' => 'mysql',
      ];

However, editing `settings.php` manually for database connection is
usually necessary only if you are applying `local-docker` on top of an
existing Skeleton -project.

### Daily usage

Execute `./ld` to see some options to control your local docker stack.
Behind the scenes script starts and stops files syncing and containers.

More importantly using it helps you to not delete database by mistake,
but executes (and restores) database backups in `db_dumps/` -folder,
keeping most recent as the restorable dump. 

#### Initial start

It is recommended to start the project first time with:

    $ ./ld init

and answer some question to set up things properly.

#### Start local

If containers are not pulles/built yet, this will do it for you. 

    $ ./ld up

#### Stop local

Put local to sleep:

    $ ./ld stop 

Stop (ie. remove volumes unless they are persistent):

    $ ./ld down

Note that files sync must be started in order to start other containers,
and it keeps 1-n pcs of containers running when it is started.

#### Watch filesync logs

It may be helpful to keep eye on files sync logs.
 
    $ docker-sync logs -f

#### Create a snapshot/backup of database

This is done automatically when you stop or destroy your containers.

    $ ./ld dump

#### Restore (old) db backup
 
 Put a file in `db_dumps/` -folder and create a symlink pointing to it:
 
    $ ln -s MY_GZIPPED_MYSQLDUMP_FILE.sql.gz ./db_dumps/db-container-dump-LATEST.sql.gz
    $ ./ld restore


#### Composer, Drush, Drupal

Composer, Drush or Drupal console are aliased inside `php` container as
well as commands in `./ld [drush|drupal|composer]`.

    $ docker-compose exec php bash
    /var/www # drush status
    /var/www # composer require drupal/pathauto:^1
    /var/www # drupal ce --exclude-config-hash --directory=../config/sync

These commands are funcionality-wise the same:

    $ ./ld drush status
    $ ./ld composer require drupal/pathauto:^1
    $ ./ld drupal ce --exclude-config-hash --directory=../config/sync

You can also execute commands directly in the shell:

    $ docker-compose exec php bash -c "drush status" # OR $ ./ld drush status

#### Xdebug

`php` container has Xdebug installed. It is turned on by default, and 
controlled by varialble `PHP_XDEBUG_REMOTE_ENABLE` in `.env` file. 

Get or set status with this command:
`./ld xdebug ['on'|1'|'off'|0]`

#### Compile CSS

Look at the `nodejs` -container in `docker-compose*.yml`, correct file
paths and enable it. Launch the project again to get the container
booted up.

You can expose nodejs container logs with:

    $ docker-compose logs -f nodejs

#### Xdebug

`php` -container has Xdebug up and running. `php` tries to connect to
IDE's Xdebug server on port `9010` when any PHP is executed:

    xdebug.remote_enable = 1
    xdebug.remote_port = 9010
    ; Docker for Desktop (on OSX at least) maps host.docker.internal to
    ; host machine. 
    xdebug.remote_host = host.docker.internal

Port `9010` is being used to avoid collision with possible php-fpm
running on the host on port `9000`.

This Xdebug configuration is initially set
in the base image this project is using (`xoxoxo/php-container`).
However this can be overridden for example in
[95-drupal-development.ini -file (PHP 7.2)](./docker/build/php7.2//conf.d/95-drupal-development.ini)
, and Xdebug's active config can be checked either from Drupal
(`admin/reports/status/php`) or with command

    $ docker-compose exec php sh -c 'exec /usr/local/bin/php -i |grep xdebug'

**Note:** You should set your IDE to use port `9010` for Xdebug in order
for IDE to setup a Xdebug listener to the port Xdebug is trying to
connect to on your host. 

#### Convenience "alias" for ./ld.sh

If you find the `./` prefix tedious when using ld, you could add the following
alias to your shell startup files. In order to not interfere with `/usr/bin/ld`,
`ld` as alias should be avoided.

    function lld() { if [[ -x "$(pwd)/ld.sh" ]] ; then "$(pwd)/ld.sh" $@; else echo "ld.sh not found in current directory"; fi }

Then, you can use `lld` instead of `./ld` or `./ld.sh`

## Projects in parallel?

Docker volumes are using volume names from `docker-composer.yml` (see
root-level key `volumes`). If you collapse with other projects: 

1. stop file sync and local (`./ld down`) if needed
2. clean up your volumes `./ld nuke-volumes` if needed
3. rename all `webroot-sync-*` -named volumes in `docker-compose.yml` and
  `docker-sync.yml` -files
4. start your local again `./ld up` and optionally restore database
   `./ld restore`
   
Another thing that may be needed is changing exposed ports. As an
example `nginx` exposes port 80 and only one project can use the port at
a time in the same IP address. Separating IP addresses per project
should be enough, but in case you bump into weird issues you can always 
change exposed ports in `.env` file, look for variable names starting
`CONTAINER_PORT_`.

### Local ports

Docker exposes services to host using ports configured in
[`.env -file`](./.env) file. Access to these ports is by default limited
to the host machine loopback interface (`127.0.0.1`) for security
(configurable). Currently the default exposed services and ports are:

-   **Nginx** ports 80, 443
-   **Adminer** port 8080 - manage databases via UI, host: `db`, user `root`, password `root_password`
-   **MySQL** port 3306 - use this with - say - SequelPro
-   **Mailhog** port 8025 - catches all emails sent by PHP

Ports can be configured in [`.env -file`](./.env) file. It is a good
practise to share the `.env` file when bringing new developers into the
project. However, `.env` file should not be committed to project
repository, but non-secure information can be shared via project
repository's `REAMDE.md` -file.

Note that all containers can access other containers services using
Docker's internal networking. Containers connect between each other by
IP addresses, which are automatically resolved using container names.

**NOTE:** Port binds for **local development** must be defined with the
localhost IP address to restrict access to your host machine (restricted
from current network - ie. everybody else in the same wi-fi).

## Customize ld -script variables

Main script supports `.env` -file overrides. You can override any
configs found in the upper part of `ld.sh` -file by changing variable
values.

File should contain key=value -pairs, such as

    # Comment starts with hash.
    MYSQL_ROOT_PASSWORD=some_password
    ANOTHER_KEY=the-value

## ISSUES 

#### Local-docker does not start

1. `Bind for 0.0.0.0:80: unexpected error (Failure EADDRINUSE)`
  
   Turn of yor local (on Mac) web server (Apache, Nginx, whatever):
   
       $ sudo apachectl stop && sudo service nginx stop

    Turn off your local MySQL (on Mac):  
    > System preferences -> MySQL ->stop
    
    Check also "Projects in parallel" -section. Other projects may have
    acclaimed ports your project is trying to use.
 

#### Local files not getting synced

If you feel file sync is not working properly, start by checking logs
and editing some files that should be synced:

    $ docker-sync logs -f

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
 
    $ docker kill $(docker ps -q) # Stop all containers.
    $ docker container prune # Remove all stopped containers.
    $ docker volume prune # Remove all unused local volumes.
        
If even that does not help, clean up EVERYTHING Docker -related
(downloaded images, created volumes and containers).

**BE WARNED** This will delete ALL volumes, downloaded images and
containers in ALL Docker projects across your whole laptop. Sorts of
resets everything else but Docker configuration.

    $ docker system prune

#### Docker-stack does not start

`mkmf.rb can't find header files for ruby at /System/Library/Frameworks/Ruby.framework/Versions/2.3/usr/lib/ruby/include/ruby.h`

You have probably updated Xcode or Command Line Tools but have not yet
approved a new license.

Makes sure you have Command Line Tools installed:

    $ xcode-select --install

After initial Command Line Tools installation and updates may need to
accept the license.

Another option is to install Xdoce from the App store, launch the application
and approve the license during the initial start. **However**, for the Docker Sync full Xcode is unnecessary, Command Line Tools can handle what's needed.

If you get this error: `xcode-select: error: tool 'xcodebuild' requires
Xcode, but active developer directory
'/Library/Developer/CommandLineTools' is a command line tools instance`
you should also reset the command line tools path with
 
    $ sudo xcode-select -r

## Why my favourite feature is not there?

This is the initial version of the local-docker. Redis, Solr and others
are coming once the need arises.

**Asking help from your colleagues is very recommended, and pull
requests even more so!**

