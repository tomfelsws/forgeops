#!/bin/bash

CONFIG_DIR=$BATCH_DIR/../../config
SOFTWARE_DIR=$BATCH_DIR/../../software
env_common_dir="${BATCH_DIR}/../../environments/common"
env=$1
env_dir="${BATCH_DIR}/../../environments/$1"
server_to_configure=${2}

# check if configuration folder exists
if ! stat ${env_common_dir} > /dev/null 2>&1 ; then
   	echo "Configuration folder [${env_common_dir}] not found, quitting..."
	exit 1
fi
if ! stat ${env_dir} > /dev/null 2>&1 ; then
   	echo "Configuration folder [${env_dir}] not found, quitting..."
	exit 1
fi

# source configuration files
common_env_properties_file=${env_common_dir}/opendj/env.properties
env_properties_file=${env_dir}/opendj/env.properties
[ -f "${common_env_properties_file}" ] && source "${common_env_properties_file}"
[ -f "${env_properties_file}" ] && source "${env_properties_file}"

common_server_properties_file=${env_common_dir}/opendj/${server_to_configure}
server_properties_file=${env_dir}/opendj/${server_to_configure}
[ -f "${common_server_properties_file}" ] && source "${common_server_properties_file}"
[ -f "${server_properties_file}" ] && source "${server_properties_file}"


USER=$(whoami)
opendjHome=${opendjExtractTargetPath}/opendj
binDir="${opendjHome}/bin"
JAVA_HOME_BIN="${JAVA_HOME}/bin"
passwordFile=${binDir}/.pass
