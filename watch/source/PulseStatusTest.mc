using Toybox.Lang as Lang;
using Toybox.Test as Test;

(:test)
function testStatusMessageIsShown(logger as Test.Logger) as Lang.Boolean {
    var text = parseStatusMessage({ "v" => 1, "type" => "status", "text" => "pulse ctx 36%" });
    return text != null && text.equals("pulse ctx 36%");
}

(:test)
function testLongStatusIsCut(logger as Test.Logger) as Lang.Boolean {
    var text = parseStatusMessage({
        "v" => 1, "type" => "status",
        "text" => "0123456789012345678901234567890123456789"
    });
    return text != null && text.length() == 30 && text.equals("0123456789012345678901234567..");
}

(:test)
function testNonStatusMessagesAreIgnored(logger as Test.Logger) as Lang.Boolean {
    return parseStatusMessage(null) == null
        && parseStatusMessage("status") == null
        && parseStatusMessage({ "v" => 2, "type" => "status", "text" => "x" }) == null
        && parseStatusMessage({ "v" => 1, "type" => "request", "text" => "x" }) == null
        && parseStatusMessage({ "v" => 1, "type" => "status", "text" => "" }) == null
        && parseStatusMessage({ "v" => 1, "type" => "status", "text" => 42 }) == null
        && parseStatusMessage({ "v" => 1, "type" => "status" }) == null;
}

(:test)
function testStatusPageKeepsFields(logger as Test.Logger) as Lang.Boolean {
    var page = parseStatusPage({
        "v" => 1, "type" => "status", "text" => "pulse ctx 59%",
        "title" => "Claude", "ctx" => 59,
        "lines" => ["pulse", "Opus 5.5", "rb ba2d0b1a", "14:25", "dropped"]
    });
    if (page == null) {
        return false;
    }
    var p = page as Lang.Dictionary;
    return p["title"].equals("Claude") && p["ctx"] == 59
        && (p["lines"] as Lang.Array).size() == 4 && (p["lines"] as Lang.Array)[1].equals("Opus 5.5");
}

(:test)
function testStatusPageFallsBackToText(logger as Test.Logger) as Lang.Boolean {
    var page = parseStatusPage({ "v" => 1, "type" => "status", "text" => "just text", "ctx" => 140 });
    if (page == null) {
        return false;
    }
    var p = page as Lang.Dictionary;
    var lines = p["lines"] as Lang.Array;
    return p["title"].equals("Claude") && p["ctx"] == null
        && lines.size() == 1 && lines[0].equals("just text");
}
