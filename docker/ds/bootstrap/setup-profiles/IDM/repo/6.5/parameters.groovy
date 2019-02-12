/*
 * Copyright 2018 ForgeRock AS. All Rights Reserved
 *
 * Use of this code requires a commercial software license with ForgeRock AS.
 * or with one of its affiliates. All use shall be exclusively subject
 * to such license between the licensee and ForgeRock AS.
 */

define.stringParameter "backendName" \
       help "IDM repository backend database name" \
       defaultValue "idmRepo" \
       advanced()

define.domainParameter "domain" \
        help "Domain name translated to the base DN for IDM external repository data. ",
             "Each domain component becomes a \"dc\" (domain component) of the base DN. ",
             "This profile prefixes \"dc=openidm\" to the result. ",
             "For example, the domain \"example.com\" translates to the base DN \"dc=openidm,dc=example,dc=com\"." \
        description "IDM external repository domain" \
        property "DOMAIN" \
        defaultValue "example.com"
