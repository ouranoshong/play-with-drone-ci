#!/bin/sh

# Pre Set
set -x

# Set ENV
export GO111MODULE=on                              

# Set Var
Src=../                                             
Out="app"
Options="-a -installsuffix cgo -o"

# Build
go version
go env

CGO_ENABLED=0 go build -o ${Out} ${Src}

# Package
tar -zcvf release.tar.gz ../www ./*