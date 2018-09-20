#!/usr/bin/env bash

mvn clean verify dependency:copy-dependencies &&\
docker build -t lds-neo4j:dev -f Dockerfile-dev .
