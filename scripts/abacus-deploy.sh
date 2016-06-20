#!/bin/bash

set -e

function mapRoutes {
  if [ -z "$1" ]; then
     echo "Cannot map app without a name !"
     exit 1
  fi
  if [ -z "$2" ]; then
    echo "Unknown number of instances !"
    exit 1
  fi

  local APP_NAME=$1
  local INSTANCES=$(expr $2 - 1)
  local APP_URL=$(cf app $APP_NAME-0 | awk '{if (NR == 7) {print $2}}')
  local APP_DOMAIN=${APP_URL/$APP_NAME-0./}

  if [ -z "$APP_DOMAIN" ]; then
    echo "Unknown domain !"
    exit 1
  fi

  echo "Mapping $2 (0-$INSTANCES) instances of $APP_NAME in $APP_DOMAIN domain ..."
  for i in `seq 0 $INSTANCES`;
  do
    cf map-route "$APP_NAME-$i" $APP_DOMAIN --hostname "$APP_NAME"
  done
}

function show_help {
  cat << EOF
Usage: ${0##*/} [-hdb]

Deploy Abacus
  -h,-? display this help and exit
  -x    drop database service instance
  -c    copy config
  -s    stage applications
  -d    create and bind service instance
  -m    map app routes
EOF
}

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables
drop_database=0
create_database=0
copy_config=0
stage_apps=0
map_routes=0

while getopts "h?xdcsm" opt; do
    case "$opt" in
      h|\?)
        show_help
        exit 0
        ;;
      x)  drop_database=1
        ;;
      c)  copy_config=1
        ;;
      s)  stage_apps=1
        ;;
      d)  create_database=1
        ;;
      m)  map_routes=1
        ;;
    esac
done

shift $((OPTIND-1))
[ "$1" = "--" ] && shift

echo "Arguments:"
echo "  drop_database='$drop_database'"
echo "  create_database='$create_database'"
echo "  copy_config='$copy_config'"
echo "  stage_apps='$stage_apps'"
echo "  map_routes='$map_routes'"
echo "  leftovers: $@"
echo ""

if [ $copy_config = 1 ]; then
  echo "Copying config ..."
  cp -R ~/workspace/abacus-config/* ~/workspace/cf-abacus
  echo ""
  echo "Rebuilding to apply config changes ..."
  echo ""
  cd ~/workspace/cf-abacus && npm run rebuild
fi

if [ $drop_database = 1 ]; then
  set +e
  unbind-all-apps.sh db
  set -e
fi

if [ $stage_apps = 1 ]; then
  echo ""
  echo "Delete apps in parallel. We expect errors due to missing routes..."
  set +e
  delete-all-apps.sh
  set -e
  echo ""
  echo "Delete apps. This time errors are NOT ok."
  delete-all-apps.sh
fi

if [ $drop_database = 1 ]; then
  echo ""
  echo "!!!! Dropping database in 5 seconds !!!!"
  echo ""
  echo "Interrupt this script with Ctrl-C to keep the DB intact"
  echo ""
  sleep 5s
  cf ds db -f
fi

if [ $stage_apps = 1 ]; then
  npm run cfstage -- large
  cf d -r -f abacus-pouchserver
  cf d -r -f abacus-authserver-plugin
fi

if [ $map_routes = 1 ]; then
  mapRoutes abacus-usage-collector 6
  mapRoutes abacus-usage-reporting 6
fi

if [ $create_database = 1 ]; then
  echo "Creating new DB service instance ..."
  cf cs mongodb v3.0-container db
  bind-all-apps.sh db
fi

start-all-apps.sh
cf a

echo "Restarting failed apps ..."
restart-failed-apps.sh
cf a

echo ""
echo ""
echo "Deploy finished"
