/*
 * Copyright 2018-2019 ForgeRock AS. All Rights Reserved
 *
 * Use of this code requires a commercial software license with ForgeRock AS.
 * or with one of its affiliates. All use shall be exclusively subject
 * to such license between the licensee and ForgeRock AS.
 */

ds.addBackend backendName, baseDn
ds.addSchemaFiles()
// CTS v2 Indexes
ds.addIndex "coreTokenUserId", "equality"
ds.addIndex "coreTokenString01", "equality"
ds.addIndex "coreTokenString02", "equality"
ds.addIndex "coreTokenString03", "equality"
// There are no searches that filter on the following, so avoid maintenance overheads by not indexing them:
// coreTokenString04 stores the session's latestAccessTimeInMillis.
// coreTokenString05 stores the session's sessionID.
// coreTokenString06 stores the session's sessionHandle.
ds.addIndex "coreTokenString08", "equality"
ds.addIndex "coreTokenString09", "equality"
ds.addIndex "coreTokenString10", "equality"
// There are no searches that filter on the following, so avoid maintenance overheads by not indexing them:
// coreTokenString11 stores the session's realm.
// As the realm values are not distinct enough, indexing on it would cause a performance bottleneck on writes.
// coreTokenString12 stores the session's creationTime.
ds.addIndex "coreTokenString14", "equality"
ds.addIndex "coreTokenString15", "equality"
ds.addIndex "coreTokenInteger01", "equality"
ds.addIndex "coreTokenInteger02", "equality"
ds.addIndex "coreTokenInteger03", "equality"
ds.addIndex "coreTokenInteger04", "equality"
ds.addIndex "coreTokenInteger05", "equality"
// There are no searches that filter on the following, so avoid maintenance overheads by not indexing them:
// coreTokenInteger06 stores the session's maxSessionTimeInMinutes.
// coreTokenInteger07 stores the session's maxIdleTimeInMinutes.
ds.addIndex "coreTokenDate03", "equality"
ds.addIndex "coreTokenDate04", "equality"
ds.addIndex "coreTokenDate05", "equality"
ds.addIndex "coreTokenMultiString01", "equality"
ds.addIndex "coreTokenMultiString02", "equality"

ds.addIndex "coreTokenExpirationDate", "ordering"
ds.addIndex "coreTokenDate01", "ordering"
ds.addIndex "coreTokenDate02", "ordering"

String ctsDn = "ou=famrecords,ou=openam-session," + baseDn
// Allow CTS admin user to modify schema
ds.config "set-access-control-handler-prop",
        "--add",
        'global-aci: (target = "ldap:///cn=schema")' \
                  + '(targetattr = "attributeTypes || objectClasses")' \
                  + '(version 3.0; ' \
                         + 'acl "Modify schema"; ' \
                         + 'allow(write) userdn="ldap:///uid=openam_cts,ou=admins,' + ctsDn + '";)'

if (dsSetupProductionModeEnabled) {
    // Add ACIs to allow the CTS user to create, search, modify, delete, and allow persistent search to the CTS
    ds.config "set-access-control-handler-prop",
              "--add",
              'global-aci: (extop="1.3.6.1.4.1.26027.1.6.1 ||' \
                                + '1.3.6.1.4.1.26027.1.6.3 ||' \
                                + '1.3.6.1.4.1.4203.1.11.1 ||' \
                                + '1.3.6.1.4.1.1466.20037 ||' \
                                + '1.3.6.1.4.1.4203.1.11.3")' \
                        + '(version 3.0; ' \
                         + 'acl "AM extended operation access"; ' \
                         + 'allow(read) userdn="ldap:///uid=openam_cts,ou=admins,' + ctsDn + '";)',
              "--add",
              'global-aci: (targetcontrol="2.16.840.1.113730.3.4.2 ||' \
                                + '2.16.840.1.113730.3.4.17 ||' \
                                + '2.16.840.1.113730.3.4.19 ||' \
                                + '1.3.6.1.4.1.4203.1.10.2 ||' \
                                + '1.3.6.1.4.1.42.2.27.8.5.1 ||' \
                                + '2.16.840.1.113730.3.4.16 ||' \
                                + '1.2.840.113556.1.4.1413 ||' \
                                + '1.3.6.1.4.1.36733.2.1.5.1 ||' \
                                + '1.3.6.1.1.12 ||' \
                                + '1.3.6.1.1.13.1 ||' \
                                + '1.3.6.1.1.13.2 ||' \
                                + '1.2.840.113556.1.4.319  ||' \
                                + '1.2.826.0.1.3344810.2.3  ||' \
                                + '2.16.840.1.113730.3.4.18  ||' \
                                + '2.16.840.1.113730.3.4.9  ||' \
                                + '1.2.840.113556.1.4.473  ||' \
                                + '1.3.6.1.4.1.42.2.27.9.5.9")' \
                        + '(version 3.0; ' \
                         + 'acl "AM extended operation access"; ' \
                         + 'allow(read) userdn="ldap:///uid=openam_cts,ou=admins,' + ctsDn + '";)',
              "--add",
              'global-aci: (targetattr="createTimestamp||' \
                                     + 'creatorsName||' \
                                     + 'modifiersName||' \
                                     + 'modifyTimestamp||' \
                                     + 'entryDN||' \
                                     + 'entryUUID||' \
                                     + 'subschemaSubentry||' \
                                     + 'etag||' \
                                     + 'governingStructureRule||' \
                                     + 'structuralObjectClass||' \
                                     + 'hasSubordinates||' \
                                     + 'numSubordinates||' \
                                     + 'isMemberOf")' \
                        + '(version 3.0; ' \
                         + 'acl "AM Operational Attributes"; ' \
                         + 'allow (read,search,compare) userdn="ldap:///uid=openam_cts,ou=admins,' + ctsDn + '";)',
              "--add",
              'global-aci: (targetcontrol="1.3.6.1.1.12 || 1.3.6.1.1.13.1")' \
                        + '(version 3.0; ' \
                          +'acl "Allow assertion control"; ' \
                         + 'allow (read) userdn = "ldap:///uid=openam_cts,ou=admins,' + ctsDn + '";)'
}

switch (tokenExpirationPolicy) {
case "am":
    // Let AM CTS reaper manage token expiration and deletion, nothing to configure on DJ side
    break
case "am-sessions-only":
    ds.addIndex "coreTokenTtlDate", "ordering"
    enableTtl backendName, "coreTokenTtlDate"
    break
case "ds":
    enableTtl backendName, "coreTokenExpirationDate"
    break
default:
    throw new IllegalArgumentException(
            "Invalid value '" + tokenExpirationPolicy + "' for 'tokenExpirationPolicy' parameter")
}

ds.importLdif "base-entries.ldif"

def enableTtl(String backendName, String ttlAttribute) {
    ds.config "set-backend-index-prop",
            "--backend-name", backendName,
            "--index-name", ttlAttribute,
            "--set", "ttl-enabled:true",
            "--set", "ttl-age:10s"
}
