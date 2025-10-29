# escape=`
# syntax=docker/dockerfile:1

#This Dockerfile installs fantom, haystack-defs, and xeto before running haxall init to create hx database named "haxall"
#To create it along with the compose file, use the following command for testing:
#docker compose -f .\docker-compose.yml run --rm -it -p 8080:8080 haxall

ARG JDK_VERSION=17

FROM eclipse-temurin:$JDK_VERSION AS base

WORKDIR /app/

ARG FAN_REL_VER=1.0.82

# Build Fantom from source
RUN <<EOF
  apt-get -q update
  apt-get -q install -y git curl unzip
  curl -fsSL https://github.com/fantom-lang/fantom/releases/download/v${FAN_REL_VER}/fantom-${FAN_REL_VER}.zip -o fantom.zip
  unzip fantom.zip
  mv fantom-${FAN_REL_VER} rel
  chmod +x rel/bin/*
  chmod +x rel/adm/*
EOF

#Get latest fantom release
RUN git clone -b master --depth 1 --single-branch https://github.com/fantom-lang/fantom fan `
  && rm -rf fan/.git*

RUN <<EOF
  echo "\n\njdkHome=${JAVA_HOME}/\ndevHome=/app/fan/\n" >> rel/etc/build/config.props
  echo "\n\njdkHome=${JAVA_HOME}/" >> fan/etc/build/config.props
  rel/bin/fan fan/src/buildall.fan superclean
  rel/bin/fan fan/src/buildboot.fan compile
  fan/bin/fan fan/src/buildpods.fan compile
EOF

ENV FAN_SUBSTITUTE=/app/rel/
ENV PATH=$PATH:/app/fan/bin

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
ENV PATH=$PATH:/opt/fan/bin

ENV HAXALL_DB_NAME=${HAXALL_DB_NAME:-haxall}

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