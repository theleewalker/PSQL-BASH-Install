#!/bin/bash

# This script is for use with the DevOps Challenge of installing PostgreSQL 9.6 on to a provisioned AWS EC2 instance running Ubuntu.

# This script will perform the following steps:
# 1. Set variables such as $packages, $rfolder, $dfolder, $gitloc, $sysuser, $helloscript, and $psqlcmd
# 2. Install packages based off of $packages.
# 3. Create directory: /postgres and other required.
# 4. Create system user 'postgres'.
# 5. Pull PostgreSQL from Git depot and confirm it is correct: git clone git://git.postgresql.org/git/postgresql.git.
# 6. Install PostgreSQL. ensuring the data files are stored in $dataFolder.
# 7. Start the PostgreSQL service using the pg_ctl command.
# 8. Run create_hello.sql script.
# 9. Run '/usr/local/pgsql/bin/psql -c 'select * from hello;' -U globus hello_postgres;' against newly created DB and test for succesful response.
# 10. Add production enhancement, vacuuming is enabled by default so will not be added as a cron job, s.

# Section 1 - Variable Creation


echo "Creating variables for use throughout the PSQL installation process"
# $packages is an array containing the dependencies for PostgreSQL
declare -a packages=('git' 'gcc' 'tar' 'gzip' 'libreadline5' 'make' 'zlib1g' 'zlib1g-dev' 'flex' 'bison' 'perl' 'python3' 'tcl' 'gettext' 'odbc-postgresql' 'libreadline6-dev');
# $rfolder is the install directory for PostgreSQL
rfolder='/postgres'
# $dfolder is the root directory for various types of read-only data files
dfolder='/postgres/data'
# $gitloc is the location of the PosgreSQL git repo
gitloc='git://git.postgresql.org/git/postgresql.git'
# $sysuser is the system user for running PostgreSQL
sysuser='postgres'
# $helloscript is the sql script for creating the Globus user and creating a database.
helloscript='~/scripts/create_hello.sql'
# $psqlcmd is the sql cmd that shows the content of the previously mentioned database.
psqlcmd="/postgres/bin/psql -c 'select * from hello;' -U globus hello_postgres;"

# Section 2 - Package Installation


# Ensures the server is up to date before proceeding.
echo "Updating packages..."
sudo apt-get update -y >> psqlinstall-log

# This for-loop will pull all packages from the package array and install them using apt-get
for package in "${packages[@]}";
do
	echo "Installing $package..."
	sudo apt-get install $package -y >> psqlinstall-log
	echo "$package installed."
done

# Section 3 - Create required directories


echo "Creating folder $rfolder..."
sudo mkdir $rfolder >> psqlinstall-log

echo "Creating folder $dfolder..."
sudo mkdir $dfolder >> psqlinstall-log

# Section 4 - Create system user


echo "Creating system user '$sysuser'"
sudo adduser --system $sysuser >> psqlinstall-log

# Section 5 - Pull down PSQL using git


echo "Pulling down PSQL from $gitloc"
git clone $gitloc >> psqlinstall-log

# Section 6 - Install and configure PSQL


# Configuring PostgreSQL to be installed at /postgres with a data root directory of /postgres/data
echo "Configuring PSQL"
~/postgresql/configure --prefix=$rfolder --datarootdir=$dfolder >> psqlinstall-log

echo "Making PSQL"
make >> psqlinstall-log

echo "installing PSQL"
sudo make install >> psqlinstall-log

echo "Giving system user '$sysuser' over the $dfolder folder"
sudo chown postgres $dfolder >> psqlinstall-log

# InitDB is used to create the location of the database cluster, for the purpose of this exercise it will be placed in the $dfolder under /db.
echo "Running initdb"
sudo -u postgres $rfolder/bin/initdb -D $dfolder/db >> psqlinstall-log

# Section 7 - Start PSQL


# PostgreSQL is being started, using pg_ctl as the system user postgres.
echo "Starting PSQL"
sudo -u postgres $rfolder/bin/pg_ctl -D $dfolder/db -l $dfolder/logfilePSQL start >> psqlinstall-log

# This block adds the environment variables for PostgreSQL to /etc/profile in order to set them for all users.
sudo cat >> /etc/profile <<EOL
# PostgreSQL Environment Variables

LD_LIBRARY_PATH=/postgres/lib
export LD_LIBRARY_PATH
PATH=/postgres/bin:$PATH
export PATH
EOL

# Section 8 - Add PostgreSQL to SystemD

# Here we create the PostgreSQL init.d script wth the LSB block at the beginning
sudo cat > /etc/init.d/postgresql <<EOL
#!/bin/sh
set -e

### BEGIN INIT INFO
# Provides:		postgresql
# Required-Start:	$local_fs $remote_fs $network $time
# Required-Stop:	$local_fs $remote_fs $network $time
# Should-Start:		$syslog
# Should-Stop:		$syslog
# Default-Start:	2 3 4 5
# Default-Stop:		0 1 6
# Short-Description:	PostgreSQL RDBMS server
### END INIT INFO

# Installation prefix
prefix=/postgres

# Data directory
PGDATA="/postgres/data"

# Who to run the postmaster as, usually "postgres".  (NOT "root")
PGUSER=postgres

# Where to keep a log file
PGLOG="$PGDATA/serverlog"

# versions can be specified explicitly
if [ -n "$2" ]; then
    versions="$2 $3 $4 $5 $6 $7 $8 $9"
else
    get_versions
fi

case "$1" in
    start|stop|restart|reload)
        if [ "$1" = "start" ]; then
            create_socket_directory
        fi
	if [ -z "`pg_lsclusters -h`" ]; then
	    log_warning_msg 'No PostgreSQL clusters exist; see "man pg_createcluster"'
	    exit 0
	fi
	for v in $versions; do
	    $1 $v || EXIT=$?
	done
	exit ${EXIT:-0}
        ;;
    status)
	LS=`pg_lsclusters -h`
	# no clusters -> unknown status
	[ -n "$LS" ] || exit 4
	echo "$LS" | awk 'BEGIN {rc=0} {if (match($4, "down")) rc=3; printf ("%s/%s (port %s): %s\n", $1, $2, $3, $4)}; END {exit rc}'
	;;
    force-reload)
	for v in $versions; do
	    reload $v
	done
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|reload|force-reload|status} [version ..]"
        exit 1
        ;;
esac

exit 0
EOL

sudo chmod 755 /etc/init.d/postgresql

sudo cat > /etc/systemd/system/multi-user.target.wants/postgresql.service <<EOL
# systemd service for managing all PostgreSQL clusters on the system. This
# service is actually a systemd target, but we are using a service since
# targets cannot be reloaded.

[Unit]
Description=PostgreSQL RDBMS

[Service]
Type=oneshot
ExecStart=/bin/true
ExecReload=/bin/true
RemainAfterExit=on

[Install]
WantedBy=multi-user.target
EOL

sudo chmod 777 /etc/systemd/system/multi-user.target.wants/postgresql.service

# Section 8 - Globus hello.sql script is ran


# The Globus script is ran to create the user, database, and populate the database.
echo "Running Globus script"
$rfolder/bin/psql -U postgres -f $helloscript

# Section 9 - hello_postgres is queried


echo "Querying the newly created table in the newly created database."
$psqlcmd

# Section 10 - Production improvements

# Important: Be sure to do periodic vacuum and analyze commands on all your PostgreSQl databases.
# The PostgreSQl documentation recommends doing this daily from cron.
# Failure to do this can seriously degrade performance, to the point where routine RLS operations (such as LRC to RLI soft state updates) timeout and fail.
