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
# 9. Run '/usr/local/pgsql/bin/psql -c 'select * from hello;' -U test hello_postgres;' against newly created DB and test for succesful response.
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
# $helloscript is the sql script for creating the test user and creating a database.
helloscript='~/scripts/create_hello.sql'
# $psqlcmd is the sql cmd that shows the content of the previously mentioned database.
psqlcmd="/usr/local/pgsql/bin/psql -c 'select * from hello;' -U test hello_postgres;"

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

echo "Giving system user '$sysUser' over the $dfolder folder"
sudo chown postgres $dfolder >> psqlinstall-log

# InitDB is used to create the location of the database cluster, for the purpose of this exercise it will be placed in the $dfolder under /db.
echo "Running initdb"
sudo -u postgres $rfolder/bin/initdb -D $dfolder/db >> psqlinstall-log

# Section 7 - Start PSQL


# PostgreSQL is being started, using pg_ctl as the system user postgres.
echo "Starting PSQL"
sudo -u postgres $rfolder/bin/pg_ctl -D $dfolder/db -l $dfolder/logfilePSQL start >> psqlinstall-log

# This block adds the environment variables for PostgreSQL to /etc/profile in order to set them for all users.
echo "#Adding for PostgreSQL" | sudo tee -a /etc/profile >> psqlinstall-log
echo "LD_LIBRARY_PATH=$rfolder/lib" | sudo tee -a /etc/profile >> psqlinstall-log
echo "export LD_LIBRARY_PATH" | sudo tee -a /etc/profile >> psqlinstall-log
echo "PATH=$rfolder/bin:$PATH" | sudo tee -a /etc/profile >> psqlinstall-log
echo "export PATH" | sudo tee -a /etc/profile >> psqlinstall-log


# The command to start PostgreSQL at launch is added to /etc/rc.local.
echo "Setup PSQL to launch on startup"
echo "sudo -u postgres /postgres/bin/pg_ctl -D /postgres/data/db -l /postgres/data/logfilePSQL start" | sudo tee -a /etc/rc.local >> psqlinstall-log

# Section 8 - Globus hello.sql script is ran


# This test script is ran to create the user, database, and populate the database.
echo "Running test script"
$rfolder/bin/psql -U postgres -f ~/scripts/hello.sql

# Section 9 - hello_postgres is queried


echo "Querying the newly created table in the newly created database."
$rfolder/bin/psql -c 'select * from hello;' -U user hello_postgres;

# Section 10 - Production improvements

# Important: Be sure to do periodic vacuum and analyze commands on all your PostgreSQl databases.
# The PostgreSQl documentation recommends doing this daily from cron.
# Failure to do this can seriously degrade performance, to the point where routine RLS operations (such as LRC to RLI soft state updates) timeout and fail.
