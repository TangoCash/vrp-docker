#!/bin/bash
echo "Start import"
java -jar ./photon.jar -nominatim-import -host ${NOMINATIM_HOST} -port 5432 -database nominatim -user nominatim -password ${NOMINATIM_PASSWORD}
echo "Start photon"
java -jar ./photon.jar -cors-any $@
