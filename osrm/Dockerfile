FROM ghcr.io/project-osrm/osrm-backend
LABEL maintainer="TangoCash"

ENV OSRM_ALGORITHM=mld \
    OSRM_THREADS=2 \
    OSRM_PORT=5000 \
    OSRM_PROFILE=caddy \
    OSRM_MAP_NAME=combine-latest \
    OSRM_GEOFABRIK_PATH=europe/germany-latest.osm.pbf \
    OSRM_NOTIFY_FILEPATH=/data/osrm_notify.txt \
    OSRM_MAX_MATCH=1000 \
    OSRM_MAX_TABLE=1000 \
    OSRM_MAX_VIAROUTE=1000

# Add requirements and install application
RUN set -ex; \
    apt-get update -q; \
    apt-get install -y --allow-unauthenticated \
        curl \
        inotify-tools \
        netcat \
        osmium-tool \
    ; \
    rm -rf /var/lib/apt/lists/*; \
    useradd --uid 5001 --create-home osrm; \
    mkdir -p /data; \
    chown -R osrm:osrm /data


COPY ./caddy.lua /opt/caddy.lua
RUN chmod 644 /opt/caddy.lua
COPY ./sprinter.lua /opt/sprinter.lua
RUN chmod 644 /opt/sprinter.lua

USER osrm:osrm
WORKDIR /home/osrm

VOLUME [ "/data" ]

COPY --chown=osrm:osrm ./entrypoint.sh /home/osrm
RUN chmod 777 /home/osrm/entrypoint.sh

ENTRYPOINT ["/home/osrm/entrypoint.sh"]
CMD ["run"]
