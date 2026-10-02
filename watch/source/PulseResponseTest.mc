using Toybox.Lang as Lang;
using Toybox.Test as Test;

(:test)
function testFreshPulseResponse(logger as Test.Logger) as Lang.Boolean {
    var nonce = "12345678-1234-1234-1234-123456789abc";
    var response = buildPulseResponse(nonce, 72, 321);

    return responseMatches(response, nonce, 72, 321);
}

(:test)
function testUnavailablePulseResponse(logger as Test.Logger) as Lang.Boolean {
    var nonce = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
    var response = buildPulseResponse(nonce, 0, 4000);

    return responseMatches(response, nonce, 0, 4000);
}

(:test)
function testPulseResponsePreservesNonce(logger as Test.Logger) as Lang.Boolean {
    var nonce = "ffffffff-eeee-dddd-cccc-bbbbbbbbbbbb";
    var response = buildPulseResponse(nonce, 199, 3000);

    return responseMatches(response, nonce, 199, 3000);
}

function responseMatches(
    response as Lang.Dictionary,
    nonce as Lang.String,
    bpm as Lang.Number,
    ageMs as Lang.Number
) as Lang.Boolean {
    return response.size() == 5
        && response["v"] instanceof Lang.Number
        && response["v"] == 1
        && response["type"] instanceof Lang.String
        && response["type"].equals("pulse")
        && response["nonce"] instanceof Lang.String
        && response["nonce"].equals(nonce)
        && response["bpm"] instanceof Lang.Number
        && response["bpm"] == bpm
        && response["ageMs"] instanceof Lang.Number
        && response["ageMs"] == ageMs;
}
