<p align="center">
  <a href="https://haxall.io/" target="_blank" rel="noopener noreferrer">
    <img src="https://haxall.io/res/haxall-logo.svg" width="550" height="128">
  </a>
</p>

# Haxall Overview
Haxall is an open source software framework for the Internet of Things.
It includes an extensive toolkit for working with [Project Haystack](https://project-haystack.org/)
data. Use it right out of the box as a flexible IoT data gateway which runs at
the edge. Haxall is written in [Fantom](https://fantom.org/) with
runtime support for both the Java VM and JavaScript environments.

See [https://haxall.io](https://haxall.io) for more more information.

# Getting Started

All the documentation is hosted on [haxall.io](https://haxall.io):

- [Setup](https://haxall.io/doc/docHaxall/Setup): install and get Haxall running
- [Build](https://haxall.io/doc/docHaxall/Build): instructions to build from source
- [Learn](https://haxall.io/doc/appendix/learn): quick links to learn more

# License
Haxall is released under the [Academic Free License 3.0](https://opensource.org/licenses/AFL-3.0).

# Running Docker Containers

[Docker Desktop](https://www.docker.com/products/docker-desktop/) must be installed and running in the background to create Docker images and containers and to run Docker containers.  Docker images must be created using Docker Compose and the below instructions.

Please note:
 - Following the below instructions will result in a local bind-mount `dbs` folder being created on your filesystem for persisting data if it does not already exist
 - A database is initialized only if a directory named according to the `HAXALL_DB_NAME` environment variable does not exist in the `dbs` folder
 - When a non-default password is not specified and a new database is created, a default password is generated and displayed in the container's standard output
 - Once the container is running, go to <i><u>http://localhost:8080</i></u> to use haxall with the configured username and password.  If the default port 8080 was not configured, then go to <i><u>http://localhost:<HAXALL_PORT></i></u> instead.

## 1. Build the image yourself with Docker Compose
- Verify Docker Desktop is installed and running.
- Download the latest release of haxall <i>(any releases before <u>Oct 24, 2025</u> will not have this functionality)</i>, or clone the repository.
- In the root folder of haxall create a file called `.env` that defines environment variables for the Docker container to be created.  An example template for this file is shown below.

```ini
HAXALL_PORT=<port>               # defaults to 8080
HAXALL_DB_NAME=<db_name>         # defaults to var
HAXALL_SU_USERNAME=<su_username> # defaults to su
HAXALL_SU_PASSWORD=<su_password> # defaults to automatically generated password
```

Note: Default values are applied to the environment variables shown above if they are not user defined.

- Run this command on a terminal in the root folder of haxall on your local system:
```bash
docker compose up
```

This command will perform the following:
  - Build an image for haxall
  - Use the newly created image to create and run a container
  - Create a local bind-mount in the `dbs` folder in the root folder of haxall
