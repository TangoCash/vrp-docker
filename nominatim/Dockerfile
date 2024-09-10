FROM mediagis/nominatim:4.4
LABEL maintainer="TangoCash"

ENV PBF_PATH=/nominatim/data/combine-latest.osm.pbf
ENV NOMINATIM_PASSWORD=qaIACxO6wMR3

RUN useradd --uid 5001 nominatim;

# Fix CORS
RUN sed -i 's/AddType text\/html .php/AddType text\/html .php\nAddType application\/json .php/g' /etc/apache2/sites-enabled/000-default.conf
