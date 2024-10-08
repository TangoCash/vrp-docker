#!/bin/bash
##
##    Docker image for OSRM Backend.
##    Copyright (C) 2020  Monogramm
##    Copyright (C) 2024  TangoCash
##
set -e

# -------------------------------------------------------------------
# Functions

log() {
  echo "[$0] [$(date +%Y-%m-%dT%H:%M:%S%:z)] $@"
}

# wait for file/directory to exists
wait_for_file() {
    WAIT_FOR_FILE=${1}
    if [ -z "${WAIT_FOR_FILE}" ]; then
        log "Missing file path to wait for!"
        exit 1
    fi

    WAIT_TIME=0
    WAIT_STEP=${2:-10}
    WAIT_TIMEOUT=${3:--1}

    while [ ! -d "${WAIT_FOR_FILE}" ] ; do
        if [ "${WAIT_TIMEOUT}" -gt 0 ] && [ "${WAIT_TIME}" -gt "${WAIT_TIMEOUT}" ]; then
            log "File '${WAIT_FOR_FILE}' was not available on time!"
            exit 1
        fi

        log "Waiting file '${WAIT_FOR_FILE}'..."
        sleep "${WAIT_STEP}"
        WAIT_TIME=$(( WAIT_TIME + WAIT_STEP ))
    done
    log "File '${WAIT_FOR_FILE}' exists."
}

wait_for_files() {
    if [ -z "${WAIT_FOR_FILES}" ]; then
        log "Missing env var 'WAIT_FOR_FILES' defining files to wait for!"
        exit 1
    fi

    for H in ${WAIT_FOR_FILES}; do
        wait_for_file "${H}" "${WAIT_STEP}" "${WAIT_TIMEOUT}"
    done

}

# wait for service to be reachable
wait_for_service() {
    WAIT_FOR_ADDR=${1}
    if [ -z "${WAIT_FOR_ADDR}" ]; then
        log "Missing service's address to wait for!"
        exit 1
    fi

    WAIT_FOR_PORT=${2}
    if [ -z "${WAIT_FOR_PORT}" ]; then
        log "Missing service's port to wait for!"
        exit 1
    fi

    WAIT_TIME=0
    WAIT_STEP=${3:-10}
    WAIT_TIMEOUT=${4:--1}

    while ! nc -z "${WAIT_FOR_ADDR}" "${WAIT_FOR_PORT}" ; do
        if [ "${WAIT_TIMEOUT}" -gt 0 ] && [ "${WAIT_TIME}" -gt "${WAIT_TIMEOUT}" ]; then
            log "Service '${WAIT_FOR_ADDR}:${WAIT_FOR_PORT}' was not available on time!"
            exit 1
        fi

        log "Waiting service '${WAIT_FOR_ADDR}:${WAIT_FOR_PORT}'..."
        sleep "${WAIT_STEP}"
        WAIT_TIME=$(( WAIT_TIME + WAIT_STEP ))
    done
    log "Service '${WAIT_FOR_ADDR}:${WAIT_FOR_PORT}' available."
}

wait_for_services() {
    if [ -z "${WAIT_FOR_SERVICES}" ]; then
        log "Missing env var 'WAIT_FOR_SERVICES' defining services to wait for!"
        exit 1
    fi

    for S in ${WAIT_FOR_SERVICES}; do
        WAIT_FOR_ADDR=$(echo "${S}" | cut -d: -f1)
        WAIT_FOR_PORT=$(echo "${S}" | cut -d: -f2)

        wait_for_service "${WAIT_FOR_ADDR}" "${WAIT_FOR_PORT}" "${WAIT_STEP}" "${WAIT_TIMEOUT}"
    done

}

# download map from Geofrabik
download_map() {
    if [ -z "${OSRM_GEOFABRIK_PATH}" ]; then
        log "Missing relative Geofabrik path 'OSRM_GEOFABRIK_PATH'!"
        exit 1
    fi
    if [ -z "${OSRM_MAP_NAME}" ]; then
        log "Missing OSRM map name 'OSRM_MAP_NAME'!"
        exit 1
    fi

    for map in ${OSRM_GEOFABRIK_PATH};
    do
        mapname=$(basename ${map})
        maps="${maps} ${mapname}"
        if [ ! -f "/data/${mapname}" ]; then
            log "Downloading OSR map '${map}' from Geofabrik..."
            curl -q -L \
                -o "/data/${mapname}" \
                "http://download.geofabrik.de/${map}"
        fi
    done
    log "Download OSR map '${maps}' from Geofabrik finished."    

    if [ ! -f "${OSRM_MAP_NAME}.osm.pbf" ]; then
        (cd /data; osmium merge --overwrite ${maps} -o ${OSRM_MAP_NAME}.osm.pbf)
        log "Merged OSR maps '${maps}' to '${OSRM_MAP_NAME}.osm.pbf'"
    fi

    (cd /data; ln -sf ${OSRM_MAP_NAME}.osm.pbf ${OSRM_MAP_NAME}-${OSRM_PROFILE}.osm.pbf)
    log "Merged OSR maps '${maps}' to '${OSRM_MAP_NAME}.osm.pbf'"
}

# extract OSRM info from OSM map (pbf)
extract_map() {
    if [ -z "${OSRM_MAP_NAME}" ]; then
        log "Missing OSRM map name 'OSRM_MAP_NAME'!"
        exit 1
    fi

    log "Extracting OSRM info from map '${OSRM_MAP_NAME}-${OSRM_PROFILE}' with profile '${OSRM_PROFILE}'..."
    osrm-extract \
        -p "/opt/${OSRM_PROFILE}.lua" \
        "/data/${OSRM_MAP_NAME}-${OSRM_PROFILE}.osm.pbf"
    log "Extraction OSRM info from map '${OSRM_MAP_NAME}-${OSRM_PROFILE}' with profile '${OSRM_PROFILE}' finished."
    touch "/data/${OSRM_MAP_NAME}-${OSRM_PROFILE}.extract"

    #Keep file for nominatim
    #log "Deleting OSM map '${OSRM_MAP_NAME}'..."
    #rm "/data/${OSRM_MAP_NAME}.osm.pbf"
}

# pre-process map
preprocess_map() {
    if [ "${OSRM_ALGORITHM}" == 'ch' ]; then

        log "Pre-processing OSRM for Contraction Hierarchies..."
        osrm-contract "/data/${OSRM_MAP_NAME}-${OSRM_PROFILE}.osrm"
        log "Pre-processing for Contraction Hierarchies finished."

    elif [ "${OSRM_ALGORITHM}" == 'mld' ]; then

        log "Pre-processing OSRM for Multi-Level Dijkstra..."
        osrm-partition "/data/${OSRM_MAP_NAME}-${OSRM_PROFILE}.osrm"
        osrm-customize "/data/${OSRM_MAP_NAME}-${OSRM_PROFILE}.osrm"
        log "Pre-processing for Multi-Level Dijkstra finished."
        touch "/data/${OSRM_MAP_NAME}-${OSRM_PROFILE}.preprocess"

    else

        log "Unknown pre-processing algorithm '${OSRM_ALGORITHM}'!"
        exit 1

    fi
}

# OSRM Routed
routed() {
    if [ -z "${OSRM_MAP_NAME}" ]; then
        log "Missing OSRM map name 'OSRM_MAP_NAME'!"
        exit 1
    fi

    if [ "${1}" = '-d' ] || [ "${1}" = '--detach' ]; then
        log "Starting OSRM routing server (${OSRM_ALGORITHM}) in background..."
        nohup osrm-routed \
            --port "${OSRM_PORT}" \
            --threads "${OSRM_THREADS}" \
            --max-matching-size "${OSRM_MAX_MATCH}" \
            --max-table-size "${OSRM_MAX_TABLE}" \
            --max-viaroute-size "${OSRM_MAX_VIAROUTE}" \
            --algorithm "${OSRM_ALGORITHM}" \
            "/data/${OSRM_MAP_NAME}-${OSRM_PROFILE}.osrm" > /data/osrm.logs 2>&1 &
        echo $! > /data/osrm.pid
        log "OSRM routing server (${OSRM_ALGORITHM}) started in background (PID: $(cat /data/osrm.pid))."
    else
        log "Starting OSRM routing server (${OSRM_ALGORITHM})..."
        osrm-routed \
            --port "${OSRM_PORT}" \
            --threads "${OSRM_THREADS}" \
            --max-matching-size "${OSRM_MAX_MATCH}" \
            --max-table-size "${OSRM_MAX_TABLE}" \
            --max-viaroute-size "${OSRM_MAX_VIAROUTE}" \
            --algorithm "${OSRM_ALGORITHM}" \
            "/data/${OSRM_MAP_NAME}-${OSRM_PROFILE}.osrm"
    fi

}

# display help
print_help() {
    echo "Monogramm Docker entrypoint for OSRM Backend.

Usage:
docker exec  <option> [arguments]

Options:
    --help                    Displays this help
    download                  Download map from Geofabrik
    extract                   Extract OSRM info from OSM map (pbf)
    preprocess                Pre-process map
    routed                    OSRM Routed
    run                       Run OSRM Backend
    start                     Start OSRM Backend service
    <command>                 Run an arbitrary command
"
}

# Run OSRM Backend
run_osrm() {
    if [ ! -f "/data/${OSRM_MAP_NAME}-${OSRM_PROFILE}.osm.pbf" ]; then
        download_map
    fi
    if [ ! -f "/data/${OSRM_MAP_NAME}-${OSRM_PROFILE}.extract" ]; then
        extract_map
    fi
    if [ ! -f "/data/${OSRM_MAP_NAME}-${OSRM_PROFILE}.preprocess" ]; then
        preprocess_map
    fi

    routed
}

run_osrm_background() {
    # TODO If exist, update settings from content of ${OSRM_NOTIFY_FILEPATH}

    download_map
    extract_map
    preprocess_map

    routed --detach
}

kill_osrm() {
    if [ -f '/data/osrm.pid' ]; then
        log "Stopping OSRM Backend..."
        kill -9 $(cat /data/osrm.pid)
        rm -f '/data/osrm.pid'
        log "Stopped OSRM Backend."
    else
        log "No OSRM Backend instance running in background."
    fi
}

# Start OSRM Backend service
start() {
    run_osrm_background
    log "Initialize notification file."
    echo "$(date -u +%Y-%m-%dT%H:%M:%SZ) ${OSRM_MAP_NAME} ${OSRM_GEOFABRIK_PATH} ${OSRM_PROFILE} ${OSRM_ALGORITHM}" \
        > "${OSRM_NOTIFY_FILEPATH}"

    # with inotify-tools installed, watch for modification of notification file
    while inotifywait -e modify "${OSRM_NOTIFY_FILEPATH}"; do
        kill_osrm

        run_osrm_background
    done
}

# -------------------------------------------------------------------
# Runtime

# Execute task based on command
case "${1}" in
  # Management tasks
  ("--help") print_help ;;
  ("download") download_map ;;
  ("extract") extract_map ;;
  ("preprocess") preprocess_map ;;
  ("routed") routed ;;
  # Service tasks
  ("run") run_osrm ;;
  ("start") start ;;
  # TODO Add a cron task ?
  # Arbitrary command
  (*) exec "$@" ;;
esac
