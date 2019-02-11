def phone = identity.getAttribute("telephoneNumber");

if(phone) {
    logger.message("Phonenumber received from identity: " + phone);
}

def authLevel = session.getProperty("AuthLevel");

logger.message("AuthLevel received from session: " + authLevel);


if(authLevel.find( /\d+/ ).toInteger() < 2 && phone) {
    def hotpChainName = ["Sesam-HOTP-StepUp"];
    advice.put("AuthenticateToServiceConditionAdvice", hotpChainName);
    //def authLevelArray = [2];
    //advice.put("AuthLevelConditionAdvice", authLevelArray);
    authorized = false;
} else {
    authorized = true;
}