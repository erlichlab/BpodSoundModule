#!/bin/bash

epid=`pgrep -f AudioService`
renice -n -19 -p $epid