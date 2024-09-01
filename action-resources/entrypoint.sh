#!/bin/bash
# https://docs.github.com/en/actions/creating-actions/dockerfile-support-for-github-actions
set -e

# Load the configuration from the environment variables
export CONFIG_FILE="${GITHUB_WORKSPACE}/${CONFIG_FILE:-algolia.json}"
export BUILD_DIR="${GITHUB_WORKSPACE}/${BUILD_DIR:-build}"

# Sanity checks
[[ ! -f "$CONFIG_FILE" ]] &&
	echo >&2 "$CONFIG_FILE: file not found" &&
	exit 1

# Load the configuration from the file
export CONFIG="$(cat "${CONFIG_FILE}" | jq --raw-output 'tostring')"

# Extract the scraper configuration
SCRAPER_CONFIG=$(echo $CONFIG | jq --raw-output '.scraper // empty')
[[ -n "$SCRAPER_CONFIG" ]] &&
	export CONFIG="$(echo $CONFIG | jq --raw-output 'del(.scraper) | tostring')" ||
	true

export SCRAPER_PAGERANK_RULES="$(echo $SCRAPER_CONFIG | jq --raw-output '.page_rank_rules // empty')"
export SCRAPER_REMOVE_ATTRIBUTES=$(echo $SCRAPER_CONFIG | jq --raw-output '.remove_attributes // empty')
export SCRAPER_MAX_RECORD_BYTES=$(echo $SCRAPER_CONFIG | jq --raw-output '.max_record_bytes // empty')

if [[ -n "$OVERRIDE_HOST" ]]; then
  # If we override the host, that means we need to build the index
  # locally, so let's make sure we have the build directory available
  [[ ! -d "$BUILD_DIR" ]] &&
	  echo >&2 "$BUILD_DIR: directory not found" &&
	  exit 1

  # Figure out the local server address
  localserver_port=8080
  LOCALSERVER_HOST="localhost"
  LOCALSERVER_URL="http://${LOCALSERVER_HOST}"
  if [[ "$localserver_port" != "80" ]]; then
    LOCALSERVER_URL="${LOCALSERVER_URL}:${localserver_port}"
  fi

  export LOCALSERVER_URL
  export LOCALSERVER_HOST

  # Split the hosts to override on the ',' character
  export CONFIG="$(echo $CONFIG | sed "s#https://${OVERRIDE_HOST}#${LOCALSERVER_URL}#g")"
  export CONFIG="$(echo $CONFIG | sed "s#${OVERRIDE_HOST}#${LOCALSERVER_HOST}#g")"

  # Run a local server so we can scrap the static site
  cd "$GITHUB_WORKSPACE"

  # Use nginx to serve the static site
  echo >&2 "Starting a local server to serve static site from ${BUILD_DIR}"
  sed \
	  -e 's#\[GITHUB_WORKSPACE\]#'"$GITHUB_WORKSPACE"'#g' \
	  -e 's#\[SERVE_PORT\]#'"$localserver_port"'#g' \
	  /nginx.conf.template > /tmp/nginx.conf
  mkdir -p /tmp/logs
  nginx -p /tmp -c /tmp/nginx.conf

  # Wait until localserver is up
  tries=0
  while ! curl -s "${LOCALSERVER_URL}" > /dev/null; do
    echo "Waiting for local server to start..."
    sleep 5
    tries=$((tries + 1))
    if [ $tries -gt 12 ]; then
      echo "Local server did not start in time"
      exit 1
    fi
  done
  echo >&2 "Local server is up"
fi

# Go to the root directory
cd $WORKDIR

if [[ -n "$@" ]]; then
  # If arguments are provided, run that command
  bash -c "$@"
else
  # Default to run the indexing
  index
fi
