#! /bin/bash

if [ -n "$1" ]; then
    worker_cnt=$1
else
    worker_cnt=1
fi

mkdir -p upstream-server/logs

upstream_server_cmd="openresty -p upstream-server -c conf/nginx.conf"

trap 'onCtrlC' INT
function onCtrlC () {
    sudo killall wrk
    sudo killall openresty
    sudo killall nginx
    docker rm -f kong-dbless
    sudo ${upstream_server_cmd} -s stop || exit 1
}

sudo ${upstream_server_cmd} || exit 1

sleep 3

docker run -d --name kong-dbless \
  --network=host \
  -e "KONG_DATABASE=off" \
  -e "KONG_NGINX_WORKER_PROCESSES=${worker_cnt}" \
  -e "KONG_PROXY_ACCESS_LOG=/dev/stdout" \
  -e "KONG_ADMIN_ACCESS_LOG=/dev/stdout" \
  -e "KONG_PROXY_ERROR_LOG=/dev/stderr" \
  -e "KONG_ADMIN_ERROR_LOG=/dev/stderr" \
  -e "KONG_ADMIN_LISTEN=0.0.0.0:8001, 0.0.0.0:8444 ssl" \
  -e "KONG_PROXY_LISTEN=0.0.0.0:8000, 0.0.0.0:8444 ssl, 0.0.0.0:8086 ssl" \
  -e "KONG_STREAM_LISTEN=0.0.0.0:8087 ssl" \
    kong/kong-gateway:3.2

sleep 20

#############################################
echo -e "\n\nkong: $worker_cnt worker + no plugin"
echo '_format_version: "2.1"
_transform: true

services:
- name: example_service
  url: http://127.0.0.1:1980/;
  routes:
  - name: example_route
    paths:
    - /
' > kong.yaml


curl -X POST http://127.0.0.1:8001/config config=@kong.yaml

sleep 1

wrk -d 5 -c 16 http://127.0.0.1:8000/hello

sleep 1

wrk -d 5 -c 16 http://127.0.0.1:8000/hello

sleep 1

#############################################
echo -e "\n\nkong: $worker_cnt worker + prometheus plugin"

echo '_format_version: "2.1"
_transform: true

services:
- name: example_service
  url: http://127.0.0.1:1980/;
  routes:
  - name: example_route
    paths:
    - /
plugins:
- name: prometheus
' > kong.yaml


curl -X POST http://127.0.0.1:8001/config config=@kong.yaml

sleep 1

wrk -d 5 -c 16 http://127.0.0.1:8000/hello

sleep 1

wrk -d 5 -c 16 http://127.0.0.1:8000/hello

sleep 1


#############################################
echo -e "\n\nkong: $worker_cnt worker + prometheus plugin enable high cardinality metrics"

echo '_format_version: "2.1"
_transform: true

services:
- name: example_service
  url: http://127.0.0.1:1980/;
  routes:
  - name: example_route
    paths:
    - /
plugins:
- name: prometheus
  config:
    status_code_metrics: true
    latency_metrics: true
    bandwidth_metrics : true
    upstream_health_metrics : true
' > kong.yaml


curl -X POST http://127.0.0.1:8001/config config=@kong.yaml

sleep 1

wrk -d 5 -c 16 http://127.0.0.1:8000/hello

sleep 1

wrk -d 5 -c 16 http://127.0.0.1:8000/hello

sleep 1