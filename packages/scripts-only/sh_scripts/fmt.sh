#!/bin/sh

set -e

echo "##### Lint and format #####"

aptos move fmt

aptos move lint \
  --named-addresses vault_core_addr=0x10000 # dummy address
