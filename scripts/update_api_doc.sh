#!/bin/sh

cd ./Xcode

jazzy \
  --clean \
  --author Yuki Takei \
  --author_url https://github.com/noppoMan/SlimaneHTTP \
  --github_url https://github.com/noppoMan/SlimaneHTTP \
  --module SlimaneHTTP \
  --output ../docs/api
