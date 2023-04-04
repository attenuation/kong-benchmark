#! /bin/bash

ulimited -n 500000

if [ -n "$1" ]; then
    worker_cnt=$1
else
    worker_cnt=1
fi

trap 'onCtrlC' INT
function onCtrlC () {
    sudo killall wrk
    sudo killall openresty
    sudo killall nginx
    docker rm -f kong-dbless
}


mkdir -p upstream-server/logs
mkdir -p fake-kong/logs

upstream_server_cmd="openresty -p upstream-server -c conf/nginx.conf"
fake_kong_cmd="openresty -p fake-kong -c conf/nginx.conf"

sed -i "s/worker_processes .*/worker_processes ${worker_cnt};/g" fake-kong/conf/nginx.conf
sudo ${upstream_server_cmd} || exit 1
sudo ${fake_kong_cmd} || exit 1

#############################################
echo -e "\n\n upstream server"

sleep 1

wrk -d 10 -c 16 http://127.0.0.1:1980/hello

sleep 1

wrk -d 10 -c 16 http://127.0.0.1:1980/hello


sleep 3

docker run -d --name kong-dbless \
  --network=host \
  -e "KONG_DATABASE=off" \
  -e "KONG_LOG_LEVEL=error" \
  -e "KONG_PROXY_ACCESS_LOG=off" \
  -e "KONG_PROXY_STREAM_ACCESS_LOG=off" \
  -e "KONG_ADMIN_ACCESS_LOG=off" \
  -e "KONG_STATUS_ACCESS_LOG=off" \
  -e "KONG_NGINX_MAIN_WORKER_RLIMIT_NOFILE=500000" \
  -e "KONG_NGINX_EVENTS_WORKER_CONNECTIONS=500000" \
  -e "KONG_UPSTREAM_KEEPALIVE_MAX_REQUESTS=100000" \
  -e "KONG_NGINX_HTTP_KEEPALIVE_REQUESTS=100000" \
  -e "KONG_UPSTREAM_KEEPALIVE_POOL_SIZE=100000" \
  -e "KONG_PROXY_LISTEN=0.0.0.0:8000 reuseport backlog=16384, 0.0.0.0:8443 http2 ssl reuseport backlog=16384" \
  -e "KONG_NGINX_WORKER_PROCESSES=${worker_cnt}" \
    kong/kong-gateway:3.2

sleep 20

#############################################
echo -e "\n\nfake kong: $worker_cnt worker"

sleep 1

wrk -d 10 -c 16 http://127.0.0.1:1981/hello

sleep 1

wrk -d 10 -c 16 http://127.0.0.1:1981/hello

sleep 1


#############################################
echo -e "\n\nkong: $worker_cnt worker + no plugin"
kong_yaml='_format_version: "2.1"
_transform: true

services:
- name: example_service
  url: http://127.0.0.1:1980/;
  routes:
  - name: example_route
    paths:
    - /
'


curl -X POST http://127.0.0.1:8001/config -d "config=$kong_yaml" > /dev/null

sleep 1

wrk -d 10 -c 16 http://127.0.0.1:8000/hello

sleep 1

wrk -d 10 -c 16 http://127.0.0.1:8000/hello

sleep 1

#############################################
echo -e "\n\nkong: $worker_cnt worker + prometheus plugin"

kong_yaml='_format_version: "2.1"
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
'


curl -X POST http://127.0.0.1:8001/config -d "config=$kong_yaml" > /dev/null

sleep 1

wrk -d 10 -c 16 http://127.0.0.1:8000/hello

sleep 1

wrk -d 10 -c 16 http://127.0.0.1:8000/hello

sleep 1


#############################################
echo -e "\n\nkong: $worker_cnt worker + prometheus plugin enable high cardinality metrics"

kong_yaml='_format_version: "2.1"
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
'


curl -X POST http://127.0.0.1:8001/config -d "config=$kong_yaml" > /dev/null

sleep 1

wrk -d 10 -c 16 http://127.0.0.1:8000/hello

sleep 1

wrk -d 10 -c 16 http://127.0.0.1:8000/hello

sleep 1

sudo killall wrk
sudo killall openresty
sudo killall nginx
docker rm -f kong-dbless
