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
         $ brew cask install docker
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
when is being synced.

**Pros** No rotten local development environments ever again! At least
for the handful of years a head of you. The trick is local environment
is not **built** locally, but loaded from the Docker hub as-is (apart
for some minor *config* adjustments).

## Usage

Main usage is done using a `ld.sh `script: `./ld`. Executing the scrip
without no arguments gives you command list.

### Start using local-docker

This tool can be used both as a base for new Drupal 8 projects and as a
local development tool for Skeleton based projects (known by Exove
developers).

#### New project
Clone this repository as your project folder, remove .git -folder and
launch the setup:

        $ git clone git@github.com:Exove/local-docker.git my-project
        $ cd my-project
        $ rm -rf .git
        $ ./ld init

#### Existing project
 
Copy all of this repository on top of your current project.

        db_dumps/
        docker/
        ld.sh 
        ld  # symlink to ld.sh

Open your favourite terminal, type `./ld` and hit \[ENTER]. If you get
an error, ensure `ld.sh` has execute permission:

        chmod 0744 ld.sh

Initial setup asks if you is a Skeleton based project. If you have no
idea what does it mean, do not use it. 

        $ ./ld init # asks if you what config to use (Skeleton or not).
        
If you are applying `local-docker` on a Skeleton -based project, see
"Skeleton" -section .

### Local IP address and domains

This is not needed unless you wish to use a local domain (ie. type
something other than IP address 0.0.0.0 in your browser).

Use custom IP alias per project to keep your own `/etc/hosts` -file
sane. Safe IP address ranges are `10.` and `192.168.*`.

1.  **A) Create alias to your loopback -address** with a specific IP
    address (you will need to repeat this step after each reboot unless
    you do also step 2.):

          $ sudo ifconfig lo0 alias 10.10.10.10

    More info in "Local IP addresses and ports" -section

    **OR B) Make loopback -alias to be loaded automatically (MacOS only)**

    1.  Copy [this plist -file](docker/docker-for-mac-ip-alias.plist) to your `/Library/LauchDaemons` (will be loaded automatically after each reboot)

              $ sudo cp PROJECT_ROOT/docker/docker-for-mac-ip-alias.plist /Library/LaunchDaemons/com.exove.net.docker_10-10-10-10_alias.plist

    2.  Run this or reboot your MacOS:

              $ launchctl load /Library/LaunchDaemons/com.exove.net.docker_10-10-10-10_alias.plist

    You should have similar configuration now in in your [loopback interface](https://en.wikipedia.org/wiki/Loopback#LOOPBACK-INTERFACE)

          $ ifconfig lo0
          lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 16384
          options=1203<RXCSUM,TXCSUM,TXSTATUS,SW_TIMESTAMP>
          inet 127.0.0.1 netmask 0xff000000
          inet6 ::1 prefixlen 128
          inet6 fe80::1%lo0 prefixlen 64 scopeid 0x1
          inet 10.10.10.10 netmask 0xffffff00   # **** ALIAS! *****
          nd6 options=201<PERFORMNUD,DAD>

    (Important line is **`inet 10.10.10.10...`**).

2.  Add your desired (local) domains to `/etc/hosts` with IP addresses.

        #######################################################
        ##############  PROJECT NAME    #######################
        10.10.10.10 mylocal.example.com mylocal.example.fi other.multilanguage.domain mylocal.de.example.com
        10.10.10.10 mailhog.local
        
It is good practise is to have each project to use live in their own IP
addresses (or range). `local-docker` lives happily behind one IP 
address.

#### Install Drupal

After setting IP addresses and domains as your project needs them point
your browser to the correct domain. If all is well adn Drupal is not yet
installed you'll be redirected to
`mylocal.example.com/core/install.php`.

Install Drupal as usual. Be default database -container (`db`) has one
database (`drupal`) and credentials for accessing (`drupal`/`drupal`).
**Database hostname should be `db`** (database container name). Docker
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
   password from `docker-composer.yml`,
   `db.environment.MYSQL_ROOT_PASSWORD`.
 
#### Skeleton

If you are applying Local-docker on a Skeleton based project start by
copying all things mentioned in "Start using local-docker" -section on
top of your project repository. 

When initial setup asks about Skeleton, answer `y`.

        $ ./ld init
        Copying Docker compose/sync files. What is project type?
         [0] New project, application built in ./app -folder "
         [2] Skeleton -proejct. Drupal in drupal/ and custom code spread in src/ folder.
        Project type: 

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

        ./ld init

and answer some question to set up things properly.

#### Start local

If containers are not pulles/built yet, this will do it for you. 

     ./ld up            # or  
     docker-sync start && docker-compose up -d

#### Stop local

Put local to sleep:

    ./ld stop # or 
    docker-compose stop [; docker-sync clean]

Stop (ie. remove volumes with content, containers):

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

Composer commands can be launched from your host (but executed inside
container):

       $ ./ld composer require drupal/pathauto:^1

Another way is run one-off commands in `php` -container:

       $ docker-compose exec php bash -c "drush status"

#### Compile CSS

Look at the `nodejs` -container in `docker-compose*.yml`, correct file
paths and enable it. Launch the project again to get the container
booted up.

You can expose nodejs container logs with:

      $ docker-compose logs -f nodejs

#### Xdebug

`php` -container has Xdebug up and running. `php` tries to connect to
IDE's Xdebug server on port `9000` when any PHP is executed:

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

#### Convenience alias

If you find the `./` prefix tedious when using ld, you could add the following
alias to your shell startup files. In order to not interfere with `/usr/bin/ld`,
`ld` as alias should be avoided.

    alias lld='if [[ -x "$(pwd)/ld.sh" ]] ; then "$(pwd)/ld.sh"; fi'

### Launch a new project

`./ld init` creates a drupal-project for you out-of-the-box (this will
take a few minutes). If you already have a `drupal/composer.json` file
you should not do that, but rather execute composer install:

       $ docker-compose exec php bash -c "composer install"
       # OR
       $ ./ld composer install

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
a time. You can change exposed ports in `docker-compose.yml` file, see
containers configuration for `ports`, format is HOST:CONTAINER. In other
words, 80:80 exposes `nginx` port `80` to host as-is, and `8080:80`
allows access to `nginx` from host via port `8080`.

### Local IP addresses and ports

Docker exposes different services via IP address `0.0.0.0` to allow access to them via all host machine IPs (_right now_ is the time to turn on your firewall if it is not yet enabled). Currently exposed services include:

-   **Nginx** ports 80, 443
-   **Adminer** port 8080 - manage databases via UI, host: `db`, user `root`, password `root_password`
-   **MySQL** port 3306 - manage databases, execute
    `$ docker-compose exec db sh -c 'mysql -h db -uroot -proot_password'`
    to connect via shell
-   **Mailhog** port 8025 - catches all emails sent by PHP

If you want to use a specific IP address or set domain names in your 
`/etc/hosts` -file, you must add an alias to host's loopback address. On
macOS this is done with the command

    $ sudo ifconfig lo0 alias 10.10.10.10

On Ubuntu 16.04 and probably other Linux variants

    $ sudo ifconfig docker0:0 10.10.10.10

**NOTE**: This must currently be done after each reboot.

Note that all containers can access other containers services  using
Docker's internal networking. Containers connect between each other by
IP addresses, which are automatically resolved using container aliases
(see service names in
[`docker-compose.yml -file`](./docker-compose.yml)).

## Customize ld -script variables

Main script supports .env -file overrides. You can override any configs
found in the upper part of `ld.sh` -file by placing a file named `.env`
in the root of the project and changing some variable values.

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
 
        $ docker kill $(docker ps -q) # Stop all containers.
        $ docker container prune # Remove all stopped containers.
        $ docker volume prune # Remove all unused local volumes.
        
If even that does not help, clean up EVERYTHING Docker -related
(downloaded images, created volumes and containers).

**BE WARNED** This will delete ALL volumes, downloaded images and
containers in ALL Docker projects across your whole laptop. Sorts of
resets everything else but Docker configuration.

        docker system prune

#### Docker-stack does not start

`mkmf.rb can't find header files for ruby at /System/Library/Frameworks/Ruby.framework/Versions/2.3/usr/lib/ruby/include/ruby.h`

You have probably updated Xcode or Command Line Tools but have not yet
approved a new license.

**Solution** 

After initial Command Line Tools installation and updates may need to
accept the license. You can do this using this command (and agreeing
with the EULA):

         $ sudo xcodebuild -license

Another option is to start Xdoce, approve the license and try again.
Optionally you can achieve the same via command line with less downloads
for you Xcode:

        $ xcode-select --install

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

