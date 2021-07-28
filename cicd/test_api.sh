#!/bin/sh

# Pre Set
set -x

# Set ENV
export GO111MODULE=on                               

# Set Var
Src=../
DB=$1        
if [ -z $1 ]; then
    DB=mgo:27017
fi

# Golang Test
echo Test Info: $@
echo $PWD

go mod tidy
go test -v --cover ${Src} --db_addr=${DB}
