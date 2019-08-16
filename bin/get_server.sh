#!/bin/bash

http_response=$(curl -s -o response.txt -w "%{http_code}"  --show-error --connect-timeout 3  -H "X-Auth-Token: $TOKEN" $BASE_URI/compute/v2.1/servers/$1  )

if [ $http_response != "200" ]; then
  # handle error
  #echo "$http_response" >&2
  cat response.txt >&2
  exit 1
else
  echo "Server returned:"
  cat response.txt
  exit 0
fi

