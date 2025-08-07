#!/bin/sh

set -e

echo "##### Running tests #####"

aptos move test \
  --dev --language-version 2.2
