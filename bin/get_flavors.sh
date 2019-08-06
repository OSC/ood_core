#!/bin/bash
 
curl -s -H "X-Auth-Token: $TOKEN" \
http://$BASE_URI/compute/v2.1/flavors \

#echo "curl $BASE_URI using token $TOKEN"
