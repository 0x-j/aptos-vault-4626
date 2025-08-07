#!/bin/sh

set -e

echo "##### Lint and format #####"

aptos move fmt

aptos move lint \
  --language-version 2.2 --named-addresses vault_core_addr=0x10000 # dummy address
