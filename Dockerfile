FROM lsiobase/python:3.11

# set version label
ARG BUILD_DATE
ARG VERSION
ARG AC2MQTT_VERSION
LABEL build_version="Version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="wjbeckett"

# set python to use utf-8 rather than ascii
ENV PYTHONIOENCODING="UTF-8"

RUN \
 echo "**** install packages ****" && \
 apk add --no-cache --virtual=build-dependencies \
	g++ \
	gcc \
	curl \
	make \
	python-dev && \
 apk add --no-cache \
        jq && \
 echo "**** install pip packages ****" && \
 pip install --no-cache-dir -U \
	paho-mqtt \
	pyyaml \
	pycrypto && \
 echo "**** Install app ****" && \
 mkdir -p /app/ac2mqtt && \
 echo "Created App folder in /app/ac2mqtt" && \
 mkdir -p /config && \
 echo "Created config folder in /config" && \
 AC2MQTT_RELEASE=$(curl -sX GET "https://api.github.com/repos/liaan/broadlink_ac_mqtt/releases/latest" \
 | jq -r '. | .tag_name'); \
 echo "Latest Release is ${AC2MQTT_RELEASE}" && \
 echo "Downloading Version ${AC2MQTT_RELEASE}" && \
 curl -o \
 /tmp/ac2mqtt.tar.gz -L \
	"https://github.com/liaan/broadlink_ac_mqtt/archive/${AC2MQTT_RELEASE}.tar.gz" && \
 echo "Downloaded successfully, extracting to /app/ac2mqtt" && \
 tar xf \
 /tmp/ac2mqtt.tar.gz -C \
	/app/ac2mqtt --strip-components=1 && \
 echo "Extrcted successfully" && \
 echo "**** Hard Coding versioning ****" && \
 echo "None" > /app/ac2mqtt/version.txt && \
 echo ${AC2MQTT_RELEASE} > /app/ac2mqtt/version.txt && \
 echo "**** cleanup ****" && \
 apk del --purge \
	build-dependencies && \
 rm -rf \
	/root/.cache \
	/tmp/*

# copy local files
COPY root/ /

# ports and volumes
VOLUME /config