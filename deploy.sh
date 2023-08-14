#!/bin/bash

rm -rf public
hugo && rsync -zav --delete public/  kriffer@172.105.249.34:/home/kriffer/kriffer-io/
