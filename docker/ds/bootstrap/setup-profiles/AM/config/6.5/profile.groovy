/*
 * Copyright 2018 ForgeRock AS. All Rights Reserved
 *
 * Use of this code requires a commercial software license with ForgeRock AS.
 * or with one of its affiliates. All use shall be exclusively subject
 * to such license between the licensee and ForgeRock AS.
 */

ds.addBackendWithDefaultUserIndexes backendName, baseDn
ds.addSchemaFiles()
// Config Indexes
ds.addIndex "sunxmlkeyvalue", "equality", "substring"
ds.addIndex "ou", "equality"  // AME-16022

// Allow admin user to modify schema
ds.config "set-access-control-handler-prop",
        "--add",
        'global-aci: (target = "ldap:///cn=schema")' \
                + '(targetattr = "attributeTypes || objectClasses")' \
                + '(version 3.0; ' \
                        + 'acl "Modify schema"; ' \
                        + 'allow (write) (userdn = "ldap:///uid=am-config,ou=admins,' + baseDn + '");)'

ds.importLdif "base-entries.ldif"
