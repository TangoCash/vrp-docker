'use strict';

require('leaflet-control-geocoder');

var defaultGeocoder = L.Control.Geocoder.nominatim({
        serviceUrl: 'http://' + window.location.hostname + ':8080/'
    });

var control = L.Control.geocoder({
  geocoder: defaultGeocoder,
  collapsed: true,
  position: 'topleft'
});

module.exports = {
  defaultGeocoder: defaultGeocoder,
  control: control
};
