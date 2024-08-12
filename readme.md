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

If you want to run the default haxall docker image on a container, rather than setting it up manually 
onto your local environment, you can do so in one of three ways. They all require that you download 
[Docker Desktop](https://www.docker.com/products/docker-desktop/) and have it running in the background. 

If you follow the instructions, you will create a local bind-mount located somewhere on your filesystem. 
Any data will be persisted there, and can be changed on the local system to affect the container and vice versa. 

Once the container is running, go to <i><u>http://localhost:8080</i></u> to use haxall. Default suuser and supass
should be printed in whatever terminal or logs you are using. 

## 1. Build the image yourself with Docker Compose
- Make sure you have dowloaded and are running Docker Desktop.
- Download the latest release of haxall <i>(any releases before <u>Jun 26, 2024</u> will not have this functionality)</i>, or clone the repository. 
- Run this command on a terminal in the root folder of haxall on your local system: 
```bash
docker compose up
```  

The command will build and run the image for haxall, creating a local bind-mount in the `dbs` folder.  

## Use Github Packages
There is a prebuilt image that rebuilds on every push to the repo, so it is the most up-to-date. You can
set it up either on command line, or through the Docker Desktop app. 

- On the repository website, go to packages, haxall, and copy the command to install the image from the command line. 
- Run that command in a terminal from anywhere.

### 2. Command Line
- After doing the above, run this command:
```bash
docker run -v ./haxall:/app/haxall/dbs -p 8080:8080 --name haxall_run ghcr.io/haxall/haxall
```

This will create a local bind-mount in a folder called `haxall`, from wherever you run the command. 

### 3. Docker Desktop
- Open the Docker Desktop app
- Go to images, the haxall image should be there. 
- On the right side under actions, hit the arrow. 
- Here are example inputs:

![A screenshot of Docker Desktop container setup. Find the image in this repo, at `/docker/docker_desktop_setup.jpg`](/docker/docker_desktop_setup.jpg)

In the example inputs, a local bind-mount will be created at the folder specified by path, in this case `C:\Apps\haxall`.