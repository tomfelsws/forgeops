/*
 * Copyright 2018-2019 ForgeRock AS. All Rights Reserved
 *
 * Use of this code requires a commercial software license with ForgeRock AS.
 * or with one of its affiliates. All use shall be exclusively subject
 * to such license between the licensee and ForgeRock AS.
 */

define.stringParameter "backendName" \
       usage "Name" \
       help "Name of the backend for storing identities" \
       defaultValue "amIdentityStore" \
       advanced()

define.stringParameter "baseDn" \
       usage "DN" \
       help "The base DN to use to store identities in" \
       defaultValue "ou=identities" \
       property "AM_IDENTITY_STORE_BASE_DN" \
       advanced()

define.passwordParameter "amIdentityStoreAdminPassword" \
       help "Password of the administrative account that AM uses to bind to OpenDJ" \
       description "AM identity store administrator password" \
       prompt "Provide the AM identity store administrator password:" \
       property "AM_IDENTITY_STORE_ADMIN_PASSWORD"
