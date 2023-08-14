---
title: Run your Java application in Docker container
date:  2021-06-11
tags: ["java", "docker", "programming"]
---

This is a small practical tutorial on how to dockerize your java application, deploy, run, and monitor that.

Let’s get started with the Docker installation. For example, we will be using Ubuntu 20.04 so we will need to install Docker engine for this Linux distribution from official repositories.

~~~sh
$ sudo apt-get update

$ sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
$ echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \   $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
$ sudo apt-get update
$ sudo apt-get install docker-ce docker-ce-cli containerd.io
~~~

More specific information and installation instruction for other Linux flavors, MacOS, Windows can be found here: https://docs.docker.com/engine/install/

For testing with Docker we are going to pick some simple Spring Boot application from here
https://github.com/kriffer/foresail-pms

There is a prepared foresail-pms-0.0.1-SNAPSHOT.jar , which will be used in our further testing. Alternatively, we can build it from sources using maven command mvn clean install

Moving on, let’s create our working directory, say, “test-docker” and put our build there.

**Creating Docker image**

Now we will need to create a simple Dockerfile, add inside some instructions to let the Docker know how to create an image.

Here is the Dockerfile:

~~~docker
FROM ubuntu:focal

ENV LANG='en_US.UTF-8' LANGUAGE='en_US:en' LC_ALL='en_US.UTF-8'

ARG ZULU_REPO_VER=1.0.0-2

RUN apt-get -qq update && \
    apt-get -qq -y --no-install-recommends install gnupg software-properties-common locales curl && \
    locale-gen en_US.UTF-8 && \
    apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0x219BD9C9 && \
    curl -sLO https://cdn.azul.com/zulu/bin/zulu-repo_${ZULU_REPO_VER}_all.deb && dpkg -i zulu-repo_${ZULU_REPO_VER}_all.deb && \
    apt-get -qq update && \
    apt-get -qq -y dist-upgrade && \
    mkdir -p /usr/share/man/man1 && \
    echo "Package: zulu17-*\nPin: version 17.30+15*\nPin-Priority: 1001" > /etc/apt/preferences && \
    apt-get -qq -y --no-install-recommends install zulu17-jdk=17.0.1-* && \
    apt-get -qq -y purge gnupg software-properties-common curl && \
    apt -y autoremove && \
    rm -rf /var/lib/apt/lists/* zulu-repo_${ZULU_REPO_VER}_all.deb

ENV JAVA_HOME=/usr/lib/jvm/zulu17-ca-amd64

RUN mkdir -p /tmp/app

COPY foresail-pms-0.0.1-SNAPSHOT.jar /tmp/app/

CMD ["java","-jar","/tmp/app/foresail-pms-0.0.1-SNAPSHOT.jar"]
~~~

In this Dockerfile I am using Ubuntu repo for the system environment, attaching OpenJDK17 repo for downloading and installing Java. 
In this example, I have chosen Azul Zulu OpenJDK distribution.

Next, creating a Docker image:

~~~sh
$ cd test-docker && sudo docker build -t test-docker .
~~~

lay back for some time while the image gets created.

Running the Docker container using our image
Once we get our Docker image test-docker created to run it as a container

~~~sh
$ sudo docker run -d --name="foresail" --memory="1g" --memory-swap="1g" -p 80:8080 test-docker
~~~

where:

- `-d` background mode;
- `–name=”foresail”` name for our container;
- `–memory=”1g”` memory limit for our container;
- `–memory-swap=”1g”` swap memory limit;
- `-p 80:8080` port redirection (<host port>:<container port>).

Alternatively, we can run the cuntainer in interactive mode that opens a terminal session
~~~sh
$ sudo docker run -it --name="foresail" --memory="1g" --memory-swap="1g" -p 80:8080 test-docker)
~~~

Now let’s check the status of our container:
~~~sh
$ sudo docker ps
CONTAINER ID IMAGE COMMAND CREATED STATUS PORTS NAMES
8207c7cadd98 test-docker "java -jar /tmp/app/…" 5 minutes ago Up 5 minutes 0.0.0.0:80->8080/tcp, :::80->8080/tcp foresail
~~~

Open a browser and type http://localhost
(there you can use user1/test for logging in)

Great, we have the application running in the Docker container!

**More useful things**

Assume we want to get attached to our container and login there as in any other Linux system. Having the container running in background mode we can open a terminal session like that:
~~~sh
$ sudo docker container exec -it test-docker /bin/bash
~~~

The session appeared and now we can check the java processes running inside the container:
~~~sh
root@8207c7cadd98:/# ps ax | grep java
1 ? Ssl 0:22 java -jar /tmp/app/foresail-pms-0.0.1-SNAPSHOT.jar
85 pts/0 S+ 0:00 grep --color=auto java
~~~

Having checked that (or done other things) we can leave that using the exit command. Sometimes we want to check how much resources the container consumes. For this there is a command:
~~~sh
$ sudo docker stats 
CONTAINER ID NAME CPU % MEM USAGE / LIMIT MEM % NET I/O BLOCK I/O PID
S8207c7cadd98 foresail 0.13% 264.8MiB / 1GiB 25.86% 34.1kB / 2.11MB 614kB / 0B 30
~~~

So, now assume we want to stop our container and delete it. It is usual in a development environment or when the configurations/deployments happen quite often. For this we can just run:
~~~sh
$ sudo docker stop foresail
~~~
and delete it:
~~~sh
$ sudo docker rm foresail
~~~
If we run
~~~sh
$ sudo docker ps
~~~
we won’t see anything running.

That’s it!

As we can see using the Docker containers is a very convenient and useful way of deploying java applications. 

Of course, it is not a comprehensive guide, however, as a starting point, might work.
