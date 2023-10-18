#!/bin/bash

set -e

DIR=$(dirname "$0")
$DIR/joinsplit/build.sh
$DIR/subtreeupdate/build.sh
$DIR/canonAddrSigCheck/build.sh
