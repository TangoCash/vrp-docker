FROM openjdk:11-jre
LABEL maintainer="TangoCash"

ENV EXTRACT_COUNTRY=all
ENV NOMINATIM_PASSWORD=qaIACxO6wMR3
ENV NOMINATIM_HOST=nominatim

# Install pbzip2 for parallel extraction
RUN apt-get update \
    && apt-get -y install \
        pbzip2 \
        wget \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --uid 5001 --create-home photon;

USER photon:photon
WORKDIR /home/photon

ADD --chown=photon:photon https://github.com/komoot/photon/releases/download/0.5.0/photon-0.5.0.jar /home/photon/photon.jar

COPY --chown=photon:photon ./entrypoint.sh /home/photon
RUN chmod 777 /home/photon/entrypoint.sh

EXPOSE 2322

ENTRYPOINT ["/home/photon/entrypoint.sh"]
