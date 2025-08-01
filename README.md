# Postgres 18 Beta Dockerfile

Builds the Postgres 18 beta from source so that it can be tested using docker.

To use, clone this repo locally, open a terminal in the repo directory and run `docker build -t postgres:18-beta1 .`.  After the build completes, you can run the image and configure it using the same environment variables used in the standard Postgres image, e.g. `docker run --rm -p 5432:5432 -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgre
 s postgres:18-beta1`.

 Important!  This performs a basic build of Postgres using the default configuration.  If want to enabled additional features you can tweak the build by following the [Postgres build documentation](https://www.postgresql.org/docs/18/install-make.html).