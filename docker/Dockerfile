# escape=`
# syntax=docker/dockerfile:1

#This Dockerfile installs fantom, haystack-defs, and xeto before running haxall init to create hx database named "haxall" 
#To create it along with the compose file, use the following command for testing:
#docker compose -f .\docker-compose.yml run --rm -it -p 8080:8080 haxall

ARG JDK_VERSION=17

FROM eclipse-temurin:$JDK_VERSION AS base

RUN set -e; `
  export DEBIAN_FRONTEND=noninteractive `
  && apt-get -q update `
  && apt-get -q install -y git unzip curl sed `
  && rm -rf /var/lib/apt/lists/* 

WORKDIR /app
ARG FAN_REL_VER=1.0.80

#FANTOM SOURCE START
# This is building fantom from source. We need to start with downloading the latest release of 
# fantom (zipfile) because fantom is required to build fantom. 
# huge help: https://gist.github.com/gvenzl/1386755861fb42db492276d3864a378c
#set is a builtin shell command:https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html#tag_18_25
RUN LATEST_ZIPURL=$(curl -s "https://api.github.com/repos/fantom-lang/fantom/releases/latest" | sed -Ene '/^[[:space:]]*"browser_download_url": *"(.+)"$/s//\1/p') `
  && curl -fsSL "${LATEST_ZIPURL}" -o fantom.zip `
  && unzip fantom.zip -d fantom `
  && mv fantom/fantom-* rel `
  && chmod +x rel/bin/* `
  && chmod +x rel/adm/* `
  && rm -rf fantom && rm -f fantom.zip 

ENV FAN_SUBSTITUTE=/app/rel

#Get latest fantom release
#theoretically, this will copy the current github files (latest release) for fantom 
#into the build without keeping all the metadata from cloning?
RUN git clone -b master --depth 1 --single-branch https://github.com/fantom-lang/fantom fan `
  && rm -rf fan/.git*

RUN <<EOF
  echo "\n\njdkHome=${JAVA_HOME}/\ndevHome=/app/fan/\n" >> rel/etc/build/config.props
  echo "\n\njdkHome=${JAVA_HOME}/" >> fan/etc/build/config.props
  rel/bin/fan fan/src/buildall.fan superclean
  rel/bin/fan fan/src/buildall.fan superclean
  rel/bin/fan fan/src/buildboot.fan compile
  fan/bin/fan fan/src/buildpods.fan compile
EOF

ENV PATH $PATH:/app/fan/bin
#FANTOM SOURCE END


#XETO START
# ADD git@github.com:Project-Haystack/xeto.git xeto
RUN git clone -b master --depth 1 --single-branch https://github.com/Project-Haystack/xeto xeto `
  && rm -rf xeto/.git*
#XETO END


#HAYSTACK-DEFS START
# ADD git@github.com:Project-Haystack/haystack-defs.git haystack-defs
RUN git clone -b master --depth 1 --single-branch https://github.com/Project-Haystack/haystack-defs haystack-defs `
  && rm -rf haystack-defs/.git*
WORKDIR /app/haystack-defs/
RUN <<EOF
  touch fan.props
  fan src/build.fan clean compile
EOF
#HAYSTACK-DEFS END



FROM eclipse-temurin:$JDK_VERSION AS devrun

COPY --from=base /app/fan/ /opt/fan/
COPY --from=base /app/haystack-defs/ /app/haystack-defs/
COPY --from=base /app/xeto/ /app/xeto/
ENV PATH $PATH:/opt/fan/bin

#This is the default database name. Can be changed during image build stage with build-args
ARG DB_NAME=haxall
ENV DB_NAME=${DB_NAME}

#This line is necessary for AWS container healthchecking
RUN apt-get -q install -y curl

#HAXALL START
COPY . /app/haxall/
WORKDIR /app/haxall
RUN <<EOF
  chmod +x bin/*
  chmod +x docker/*dockerstart.sh
  echo "path=../haystack-defs;../xeto" > fan.props
  fan src/build.fan clean compile
EOF
#HAXALL END

EXPOSE 8080

# This provides the default entrypoint and parameters, and can be overridden in command line with "--entrypoint" when doing docker run or docker compose run...
CMD ["./docker/hx_dockerstart.sh" ]