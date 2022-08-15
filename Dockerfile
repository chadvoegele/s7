FROM node:18
WORKDIR /usr/src/s7/
COPY s7 package.json /usr/src/s7/
RUN npm install
