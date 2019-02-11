#!/usr/bin/env bash
##############################################################################
# Init JDK
##############################################################################

function jdk_init() {
    export OPENDJ_JAVA_HOME=$JDK_HOME
    export PATH=$PATH:$OPENDJ_JAVA_HOME/bin
}

function deploy_jdk() {

	local jdk_dir=${JDK_HOME}
	local jdk_version=${JDK_VERSION}
	local software_dir=${SOFTWARE_DIR}

	if [ -z ${jdk_dir} ]; then
		echo "JDK_HOME value not set! ERROR ...";
		return 1;
	fi

	if [ -x ${jdk_dir} ]; then
		if [ ! -L ${jdk_dir} -a -d ${jdk_dir} ]; then 
			rm -rf ${jdk_dir}
		else
			rm ${jdk_dir} 
		fi
	fi

	echo "*** deploying jdk ${jdk_version} to ${jdk_dir}"
	echo "     o extracting"
	unzip -q ${software_dir}/jdk-${jdk_version}.zip -d ${jdk_dir}

	return ${?}
}
