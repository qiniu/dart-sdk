#!/bin/bash

# from mobx.dart TODO 用 test_coverage 代替

# Fast fail the script on failures.
set -e

OBS_PORT=9292
echo "Collecting coverage on port $OBS_PORT..."

# Start tests in one VM.
echo "Starting tests..."
dart \
  --disable-service-auth-codes \
  --pause-isolates-on-exit \
  --enable_asserts \
  --enable-vm-service=$OBS_PORT \
  test/test_coverage.dart &

pid="$!"

# Run the coverage collector to generate the JSON coverage report.
echo "Collecting coverage..."
dart pub run coverage:collect_coverage \
  --port=$OBS_PORT \
  --out=coverage/coverage.json \
  --wait-paused \
  --resume-isolates

echo "Generating LCOV report..."
dart pub run coverage:format_coverage \
  --lcov \
  --in=coverage/coverage.json \
  --out=coverage/lcov.info \
  --report-on=lib

wait "$pid"
