#!/usr/bin/env bash

if [ "$1" == "clean" ]; then
  echo "Cleaning existing neo4j data volume"
  docker rm $(docker ps -aq -f "name=docker_db-neo4j_1")
  docker volume rm docker_neo-data
  docker volume create docker_neo-data
else
  echo "Reusing existing volume docker_neo-data"
fi

ENV_FILE='docker-compose.env'
if [ -f $ENV_FILE ]; then
    export $(grep -v '^#' $ENV_FILE | xargs -0)
fi

docker-compose -f docker-compose.yml up --remove-orphans
