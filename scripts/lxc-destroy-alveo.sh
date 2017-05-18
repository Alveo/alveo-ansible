#!/bin/bash

MACHINES="alveo-solr alveo-sesame alveo-web alveo-pg alveo-rabbitmq alveo-activemq"

for m in $MACHINES; do
	sudo lxc-destroy -s -f -n $m
done
