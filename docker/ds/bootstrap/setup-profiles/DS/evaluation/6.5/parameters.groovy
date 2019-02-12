/*
 * Copyright 2018 ForgeRock AS. All Rights Reserved
 *
 * Use of this code requires a commercial software license with ForgeRock AS.
 * or with one of its affiliates. All use shall be exclusively subject
 * to such license between the licensee and ForgeRock AS.
 */

define.stringParameter "backendName" \
       help "Name of the backend for storing Example.com data" \
       defaultValue "dsEvaluation" \
       advanced()

define.domainParameter "domain" \
       help "Domain name translated to the base DN for DS evaluation identity data. ",
            "Each domain component becomes a \"dc\" (domain component) of the base DN. ",
            "For example, the domain \"example.com\" translates to the base DN \"dc=example,dc=com\". " \
       description "DS evaluation data domain" \
       property "DOMAIN" \
       defaultValue "example.com" \
       advanced()
