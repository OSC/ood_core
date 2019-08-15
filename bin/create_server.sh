#!/bin/bash

tmp=$(mktemp)
cat ../../../../bin/server_config.json | jq -M --arg foo $1 --arg image_id $2 --arg flavor_uri $3 --arg net_uuid $4 ' . + { server : { name: $foo, imageRef: $image_id, flavorRef: $flavor_uri, networks: [{uuid:$net_uuid }] }}'  >"$tmp" && mv "$tmp" ../../../../bin/server_config.json
#http_response=$(curl -s -o response.txt -w "%{http_code}"  --show-error --connect-timeout 3  -H "X-Auth-Token: $TOKEN" http://$BASE_URI/compute/v2.1/servers  )
#cat  ../../../../bin/server_config.json
http_response=$(curl -X POST -s -o response.txt -w "%{http_code}" --show-error  --connect-timeout 3 -H "Content-Type: application/json" -H "X-Auth-Token: $TOKEN" -H "ContentNova-API-Version: 2.37" -d @../../../../bin/server_config.json http://$BASE_URI/compute/v2.1/servers)

if [ $http_response != "200" ] || [$http_response != "202"]; then
    # handle error
    echo "$http_response" >&2
    cat response.txt >&2
    exit 1
else
    cat response.txt
    exit 0
fi 


