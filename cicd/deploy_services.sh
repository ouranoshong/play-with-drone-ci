#!/bin/sh
# Pre Set
set -x

# Set Var
Tag=$1
Commit=$2

if [ -z ${Tag} ]; then
    echo -e "Empty git tag given"
    exit 1
fi

ImageName=test/go-app:${Tag}
Registry=registry.example.com
BaseImage=${Registry}/${ImageName}
ContainerName=api${Tag}

# Reconfigure docker-compose.yml
sed -i "s/api(@tag)/${ContainerName}/g" docker-compose.yml
sed -i "s/(@tag)/${Tag}/g" docker-compose.yml

# Pull image and run docker container
docker pull ${BaseImage}
docker-compose up -d
docker ps
docker-compose logs mgo
docker logs api${Tag}