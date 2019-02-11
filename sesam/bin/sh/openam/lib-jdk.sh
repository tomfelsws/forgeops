#!/usr/bin/env bash
##############################################################################
# Init JDK
##############################################################################

function jdk_init() {
    export JAVA_HOME=$JDK_HOME
    export PATH=$PATH:$JAVA_HOME/bin
}
