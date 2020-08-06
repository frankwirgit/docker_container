#!/usr/bin/env bash
set -o errexit
set -o errtrace
set -o nounset

export PATH=$PATH:/home/db2inst1/sqllib/adm:/home/db2inst1/sqllib/bin

# Deploys and configures the data integration component on a db2 server.
# Execute script with arg1=<environemnt properties path>.
# i.e., ./deploy_data.sh env.properties

__dir="$(dirname $(readlink -f "$0"))"

function usage() {
  echo "Usage ${0} start|stop|deploy [-e env.properties] [-d]"
  echo "  start: Starts the DB2 instance daemon"
  echo "  stop: Stops the DB2 instance daemon"
  echo "  deploy: Configures and starts the database schema"
  echo "  -e: Name of the environment properties file to use. Defaults to default.properties"
  echo "  -d: Don't drop the existing database. Just run the schema creation script."
  exit 1
}

function parseArgs() {
  if [ ${#} -eq 0 ]; then
    usage
  fi

  action=${1}
  shift

  propsFile=default.properties
  logPath=/disk1/DB2/data-logs
  skipDrop=false
  while getopts ":e:d" opt; do
    case $opt in
      e)
        propsFile=${OPTARG}
        ;;
      d)
        skipDrop=true
        ;;
      :)
        echo "Option '-${OPTARG}' requires an argument"
        usage
        ;;
      \?)
        echo "Invalid option: -${OPTARG}"
        usage
        ;;
    esac
  done

  # Environment properties file path
  if [ ! -f "${__dir}/properties/environment/${propsFile}" ]; then
    echo "The environment '${propsFile}' is not supported. Enter a valid environment ID as argument 1."
    usage
  fi

  # Source environment properties file
  . "${__dir}/properties/environment/${propsFile}"
}

function deploy() {
  # Environment variables
  export AUTH_USER=${dbOwner}

  if [ "${skipDrop}" = "false" ]; then
    # Drop DB
    su -c "db2 force applications all" db2inst1
    su -c "db2 terminate" db2inst1
    su -c "db2stop force" db2inst1
    su -c "db2start" db2inst1
    su -c "db2 drop db MDTDB" db2inst1 || true
    su -c "db2stop force" db2inst1
    su -c "db2start" db2inst1

    # Create DB
    su -c "cd ${__dir}/${mcdrDir}; ./createdb.sh" db2inst1
  fi

  quiesceDb || true

  # Get Build number from version.properties
  sed -i 's/ /_/g' "${__dir}/version.properties"
  . "${__dir}/version.properties"
  buildNum=$(IFS=-; read -a ADDR <<< "${BUILD_NUMBER}"; echo ${ADDR[1]})
  if [ -z ${buildNum} ]; then
    echo "BUILD_NUMBER not found in 'version.properties'. Defaulting to '2.0'"
    buildNum=2.0
  fi

  # Deploy Database
  mkdir -p ${logPath}
  chown -R db2dat01:db2iadm1 ${logPath}
  su -c "cd ${__dir}/${mcdrDir}; ./deploy.sh ${dbName} ${logPath} ${buildNum} false" db2dat01 || { unquiesceDb; exit 1; }

  unquiesceDb

  su -c "cd ${mcdrDir}; ./tabpart_maint.sh MDTDB 93" db2dat01

  su -c "db2 connect to ${dbName}; db2 \"CALL SYSPROC.ADMIN_REVALIDATE_DB_OBJECTS(NULL, NULL, NULL)\"; db2 connect reset;" db2inst1
}

function stop() {
  su -c "db2stop force" db2inst1
}

function start() {
  su -c "db2start" db2inst1
}

# Quiesce the database
function quiesceDb() {
  su -c "db2 connect to ${dbName}; db2 quiesce database immediate force connections; db2 connect reset" db2inst1
}

# Unquiesce the database
function unquiesceDb() {
  su -c "db2 connect to ${dbName}; db2 unquiesce database; db2 connect reset" db2inst1
}

parseArgs ${*}

case ${action} in
  "start")
    start
    ;;
  "stop")
    stop
    ;;
  "deploy")
    deploy
    ;;
  *)
    echo "'${action}' is not a recognized command"
    usage
    ;;
esac
