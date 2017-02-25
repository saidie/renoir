#!/bin/bash

cd /redis/utils/create-cluster
./create-cluster start
yes yes | ./create-cluster create
./create-cluster watch
