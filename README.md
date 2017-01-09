# PSQL-BASH-Install
BASH script for installation of PostgreSQL on Ubuntu

This script will perform the following steps:
1. Check config file for PostgreSQL dependencies list, this will include optional dependencies as well for a total of 18.
2. Install packages based off of config file settings and log all missing dependencies.
3. Create directory: /postgres and other required.
4. Create system user 'postgres'.
5. Pull PostgreSQL from Git depot and confirm it is correct: git://git.postgresql.org/git/postgresql.git
6. Install PostgreSQL.
7. Configure PostgreSQL, ensuring the data files are stored in /postgres/data.
8. Start the PostgreSQL service using the pg_ctl command.
9. Optimize PSQL as well as securing it. This includes benchmarking/load testing.
10. Run create_hello.sql script
11. Run "/usr/local/pgsql/bin/psql -c 'select * from hello;' -U globus hello_postgres;" against newly created DB and test for successful response.
12. Add production enhancements such as support for being part of a cluster.
