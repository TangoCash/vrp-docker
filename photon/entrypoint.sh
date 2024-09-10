#!/bin/bash
echo "Start photon"
java -jar ./photon.jar -cors-any -nominatim-import -host ${NOMINATIM_HOST} -port 5432 -database nominatim -user nominatim -password ${NOMINATIM_PASSWORD} $@

