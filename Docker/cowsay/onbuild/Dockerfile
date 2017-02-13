FROM ubuntu:14.04
RUN  apt-get update && apt-get -y install cowsay && apt-get -y install fortune
ENTRYPOINT ["/usr/games/cowsay"]
CMD ["Docker is awesome!"]
ONBUILD RUN /usr/games/fortune | /usr/games/cowsay