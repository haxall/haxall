# escape=`
# syntax=docker/dockerfile:1

#This Dockerfile installs fantom, haystack-defs, and xeto before running haxall init to create hx database named "var" 

ARG JDK_VERSION=17

FROM eclipse-temurin:$JDK_VERSION AS base

RUN apt-get -q update && apt-get -q install -y git unzip curl sed

WORKDIR /app/

#FANTOM SOURCE START
# This is building fantom from source.
# download the latest release of fantom (zipfile)
# because fantom is required to build fantom
ARG FAN_REL_VER=1.0.80
RUN <<EOF
  apt-get -q update
  apt-get -q install -y curl unzip
  curl -fsSL https://github.com/fantom-lang/fantom/releases/download/v${FAN_REL_VER}/fantom-${FAN_REL_VER}.zip -o fantom.zip
  unzip fantom.zip 
  mv fantom-${FAN_REL_VER} rel
  chmod +x rel/bin/*
  chmod +x rel/adm/*
EOF

# RUN <<EOF 
#   latest_zipball=$(curl -s "https://api.github.com/repos/fantom-lang/fantom/releases/latest" | sed -Ene '/^ *"zipball_url": *"(.+)",$/s//\1/p')
#   curl -fsSL "${latest_zipball}" -o fantom.zip
#   unzip fantom.zip
#   mv fantom* rel
#   chmod +x rel/bin/*
#   chmod +x rel/adm/*
# EOF
# RUN curl -s "https://api.github.com/repos/fantom-lang/fantom/releases/latest" `
#   | sed -Ene '/^ *"zipball_url": *"(.+)",$/s//\1/p' `
#   | curl -fsSL "$latest_zipball" `
#   && unzip fantom*.zip `
#   && mv fantom* rel `
#   && chmod +x rel/bin/* `
#   && chmod +x rel/adm/* `

#Get latest fantom release
# The below line does mot work
# ADD git@github.com:fantom-lang/fantom.git fan
#theoretically, this will copy the current github files (latest release) for fantom 
#into the build without keeping all the metadata from cloning?
RUN git clone -b master --depth 1 --single-branch https://github.com/fantom-lang/fantom fan `
  && rm -rf fan/.git*

RUN echo "\n\njdkHome=${JAVA_HOME}/\ndevHome=/app/fan/\n" >> rel/etc/build/config.props `
  && echo "\n\njdkHome=${JAVA_HOME}/" >> fan/etc/build/config.props `
  && rel/bin/fan fan/src/buildall.fan superclean `
  && rel/bin/fan fan/src/buildboot.fan compile `
  && fan/bin/fan fan/src/buildpods.fan compile 

ENV FAN_SUBSTITUTE=/app/rel/
ENV PATH $PATH:/app/fan/bin
#FANTOM SOURCE END

#FANTOM IMAGE START
# # This is trying to use the fantom image on the GitHub container registry
# FROM ghcr.io/fantom-lang/fantom:latest as fantom
# #what path variables do I need to add? does this work?
# #ENV PATH $PATH:/fan
# RUN fan -version
#FANTOM IMAGE END


ARG FAN_SRC=fan
RUN fan -version

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
  ${FAN_SRC} src/build.fan
EOF
#HAYSTACK-DEFS END



FROM base AS devrun

COPY --from=base /app /app/

#HAXALL
COPY . /app/haxall/
WORKDIR /app/haxall
RUN <<EOF
  echo "path=../haystack-defs;../xeto" > fan.props
  ${FAN_SRC} src/build.fan
EOF

EXPOSE 8082

#if "var" is changed, the volume in compose needs to change
#currently the volume's container location is "/app/haxall/var"
#EX: if "var" is changed to "demo" then the location should be "/app/haxall/demo"
CMD ["hx init", "-headless", "var"]