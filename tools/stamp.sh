#!/bin/sh
# Writes version.txt: a fingerprint of every file standalone.txt lists (and the list itself).
# An install whose GitHub API is not reachable (an old Java that does not trust its certificate) uses it to see
# whether main has changed, so run this before every commit and commit version.txt with it.
cd "$(dirname "$0")/.." || exit 1
{
  cat standalone.txt
  awk '$1 == "file" || $1 == "keep" { print $2 }' standalone.txt | while read -r f; do cat "$f"; done
} | sha1sum | cut -c1-12 > version.txt
cat version.txt
