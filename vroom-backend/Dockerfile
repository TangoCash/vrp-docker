FROM debian:bookworm-slim as builder
LABEL maintainer="TangoCash"

WORKDIR /

RUN echo "Updating apt-get and installing dependencies..." && \
  apt-get -y update > /dev/null && apt-get -y install > /dev/null \
  git-core \
  build-essential \
	g++ \
  libssl-dev \
	libasio-dev \
  libglpk-dev \
	pkg-config

ARG VROOM_EXPRESS_RELEASE=v0.12.0

# clone here, since the runner image doesn't have git installed
RUN echo "Cloning and installing vroom-express release/branch ${VROOM_EXPRESS_RELEASE}..." && \
    git clone --branch $VROOM_EXPRESS_RELEASE --single-branch https://github.com/VROOM-Project/vroom-express.git

ARG VROOM_RELEASE=v1.14.0

RUN echo "Cloning and installing vroom release/branch ${VROOM_RELEASE}..." && \
    git clone --branch $VROOM_RELEASE  --single-branch --recurse-submodules https://github.com/VROOM-Project/vroom.git && \
    cd vroom && \
    make -C /vroom/src -j$(nproc)


FROM node:20-bookworm-slim as runstage

COPY --from=builder /vroom-express/. /vroom-express
COPY --from=builder /vroom/bin/vroom /usr/local/bin

WORKDIR /vroom-express

RUN apt-get update > /dev/null && \
    apt-get install -y --no-install-recommends \
      libssl3 \
      curl \
      libglpk40 \
      > /dev/null && \
    rm -rf /var/lib/apt/lists/* && \
    # Install vroom-express
    npm config set loglevel error && \
    npm install && \
    # To share the config.yml & access.log file with the host
    mkdir /conf


COPY ./entrypoint.sh /entrypoint.sh
RUN chmod 777 /entrypoint.sh
COPY ./config.yml /vroom-express/config.yml

ENV VROOM_ROUTER=osrm \
    VROOM_DOCKER=osrm \
    VROOM_LOG=/conf

HEALTHCHECK --start-period=10s CMD curl --fail -s http://localhost:3000/health || exit 1

EXPOSE 3000
ENTRYPOINT ["/bin/bash"]
CMD ["/entrypoint.sh"]
