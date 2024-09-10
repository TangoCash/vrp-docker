#!/bin/bash

# import elasticsearch index
if [ ! -d "./photon_data/elasticsearch" ]; then
    echo "Importing search index"
    java -jar ./photon.jar -cors-any -nominatim-import -host ${NOMINATIM_HOST} -port 5432 -database nominatim -user nominatim -password ${NOMINATIM_PASSWORD}
fi

# Start photon if elastic index exists

if [ -d "./photon_data/elasticsearch" ]; then
    echo "Start photon"
    java -jar ./photon.jar -cors-any $@
else
    echo "Could not start photon, the search index could not be found"
fi
