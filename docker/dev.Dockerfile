# syntax=docker/dockerfile:1

#This Dockerfile does everything without use of docker compose or compose.yaml file
#Installs fantom, haystack-defs, and xeto before running haxall stuff

ARG JDK_VERSION=17

FROM eclipse-temurin:$JDK_VERSION AS fantom

RUN apt-get -q update && apt-get -q install -y curl unzip 

WORKDIR /fantom

#download the latest release of fantom (zipfile)
RUN latest_tag=$(curl -s https://api.github.com/repos/fantom-lang/fantom/releases/latest | sed -Ene '/^ *"tag_name": *"(v.+)",$/s//\1/p') \
    && curl -JLO https://github.com/fantom-lang/fantom/archive/$latest_tag.zip \
    && unzip fantom*.zip \
    && mv fantom* rel








#stage to keep the image size down
FROM eclipse-temurin:$JDK_VERSION AS devrun

COPY --from=fantom . .

EXPOSE 8082

#if "var" is changed, the volume in compose needs to change
CMD ["hx init", "-headless", "var"]