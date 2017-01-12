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
helloscript='~/scripts/hello.sql'
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

echo "Pulling down PostgreSQL from $gitloc"
git clone $gitloc >> psqlinstall-log


# Section 6 - Install and configure PSQL

# Configuring PostgreSQL to be installed at /postgres with a data root directory of /postgres/data
echo "Configuring PostgreSQL"
~/postgresql/configure --prefix=$rfolder --datarootdir=$dfolder >> psqlinstall-log

echo "Making PostgreSQL"
make >> psqlinstall-log

echo "installing PostgreSQL"
sudo make install >> psqlinstall-log

echo "Giving system user '$sysuser' control over the $dfolder folder"
sudo chown postgres $dfolder >> psqlinstall-log

# InitDB is used to create the location of the database cluster, for the purpose of this exercise it will be placed in the $dfolder under /db.
echo "Running initdb"
sudo -u postgres $rfolder/bin/initdb -D $dfolder/db >> psqlinstall-log


# Section 7 - Start PSQL

# PostgreSQL is being started, using pg_ctl as the system user postgres.
echo "Starting PostgreSQL"
sudo -u postgres $rfolder/bin/pg_ctl -D $dfolder/db -l $dfolder/logfilePSQL start >> psqlinstall-log

# The command to start PostgreSQL at launch is added to /etc/rc.local, again using the system user postgres.
echo "Set PostgreSQL to launch on startup"
echo "sudo -u postgres /postgres/bin/pg_ctl -D /postgres/data/db -l /postgres/data/logfilePSQL start" | sudo tee -a /etc/rc.local >> psqlinstall-log

# Section 8 - Add PostgreSQL to /etc/rc.local

# This block adds the environment variables for PostgreSQL to /etc/profile in order to set them for all users.
echo "Writing PostgreSQL environment variables to /etc/profile"
cat << EOL | sudo tee -a /etc/profile

# PostgreSQL Environment Variables

LD_LIBRARY_PATH=/postgres/lib
export LD_LIBRARY_PATH
PATH=/postgres/bin:$PATH
export PATH
EOL


# Section 8 - Globus hello.sql script is ran
echo "Wait for PostgreSQL to finish starting up..."
sleep 5

# The Globus script is ran to create the user, database, and populate the database.
echo "Running Globus script"
$rfolder/bin/psql -U postgres -f $helloscript


# Section 9 - hello_postgres is queried
echo "Querying the newly created table in the newly created database."
$psqlcmd
