# broadlink_ac_mqtt_docker
Docker version of Broadlink AC to Mqtt

## Usage

Here is a docker-compose snippet to help you get started creating a container.

### docker-compose

Compatible with docker-compose v2+ schemas.

```
---
version: "2"
services:
  ac2mqtt:
    image: broadlinkac/broadlink_ac_mqtt
    container_name: ac2mqtt
    hostname: ac2mqtt
    network_mode: host
    restart: unless-stopped
    volumes:
      - ${CONFIG}/ac2mqtt:/config
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
      - TZ=${TZ}
```
The container needs to use the host network to ensure it runs on the same subnet as your AC units.


Once the container starts you will need to edit your config.yml file with your MQTT host address and username/password.

After you have edited the config.yml file, restart your container. 

You can then use a program like [MQTT Explorer](http://mqtt-explorer.com/) to watch for the `aircon` topic to start populating with your AC unit mac addresses.

# MQTT Usage

to set values just publish to /aircon/mac_address/option/value/set  new_value  :
```
/aircon/b4430dce73f1/temp/set 20
``` 

## MQTT values
| Parameter | Accepted Value | Function |
| :----: | --- | --- |
| `power` | `ON` or `OFF` | Power on/off the AC unit|
| `temp` | `16` to `32` | Sets the AC temperature. Values are between 16 and 32 and in 0.5 increments. e.g. 20.5 |
| `mode` | `AUTO`, `HEATING`, `COOLING`, `OFF` | Sets the mode of the AC unit |
| `homeassist` | `auto`, `heat`, `cool`, `off` | Same as `mode` but specifically for Home-Assistant. For Home-Assistant integration see [home-assistant](https://github.com/liaan/broadlink_ac_mqtt#home-assistant) |
| `fanspeed` | `AUTO`, `LOW`, `MID`, `HIGH` | Sets the fans speed for the AC unit |

# Home-Assistant
AC2MQTT can be utilised with Home-Assistant using MQTT auto-discovery (https://www.home-assistant.io/docs/mqtt/discovery/)

To enable MQTT autodiscovery in your Home-Assistant configuration.yaml:

```
mqtt:
  discovery: true
  discovery_prefix: homeassistant
  
```

Edit your ac2mqtt config.yml file and ensure the following is under the `mqtt` section:

```
auto_discovery_topic: homeassistant
```

The `auto_discovery_toipc` must match the `discovery_prefix` in your Home-Assistant configuration.yaml.




latest version: 1.0.15
