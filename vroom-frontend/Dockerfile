FROM node:slim
LABEL maintainer="TangoCash"

WORKDIR /

RUN apt-get update && \
    apt-get install -y git && \
    git clone --depth 1 https://github.com/VROOM-Project/vroom-frontend.git && \
    cd /vroom-frontend && \
    npm install && \
    apt purge -y git && \
    apt autoremove --purge -y && \
    apt clean && \
    apt-get autoremove -y && \
    apt-get autoclean

COPY api.js /vroom-frontend/src/config/api.js
COPY geocoder.js /vroom-frontend/src/utils/geocoder.js
COPY solution_handler.js /vroom-frontend/src/utils/solution_handler.js

WORKDIR /vroom-frontend

EXPOSE 9966

CMD ["npm", "run", "serve"]
