def authLevel = session.getProperty("AuthLevel");

logger.message("AuthLevel received from session: " + authLevel);

if(authLevel.find( /\d+/ ).toInteger() < 2) {
    def hotpChainName = ["Sesam-HOTP"];
    advice.put("AuthenticateToServiceConditionAdvice", hotpChainName);
    //def authLevelArray = [2];
    //advice.put("AuthLevelConditionAdvice", authLevelArray);
    authorized = false;
} else {
    authorized = true;
}