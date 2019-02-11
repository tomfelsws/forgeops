/*
 * Copyright 2018 ForgeRock AS. All Rights Reserved
 *
 * Use of this code requires a commercial software license with ForgeRock AS.
 * or with one of its affiliates. All use shall be exclusively subject
 * to such license between the licensee and ForgeRock AS.
 */

define.stringParameter "backendName" \
       usage "Name" \
       help "Name of the backend for storing config" \
       defaultValue "cfgStore" \
       advanced()

define.stringParameter "baseDn" \
       usage "DN" \
       help "The base DN to use to store AM's configuration in" \
       defaultValue "ou=am-config" \
       property "AM_CONFIG_BASE_DN" \
       advanced()

define.passwordParameter "amConfigAdminPassword" \
       help "Password of the administrative account that AM uses to bind to OpenDJ" \
       description "AM configuration administrator password" \
       prompt "Provide the AM configuration administrator password:" \
       property "AM_CONFIG_ADMIN_PASSWORD"

