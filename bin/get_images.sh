#!/bin/bash
 
curl -s -H "X-Auth-Token: $TOKEN" \
http://$BASE_URI/image/v2.1/images \

#echo "curl $BASE_URI using token $TOKEN"
