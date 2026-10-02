using Toybox.Lang as Lang;

// A short status line pushed from the phone app (for example Claude Code's status line):
//   { "v": 1, "type": "status", "text": "pulse · Opus 5.5 · ctx 36%" }
// The watch only displays it. It is never answered, stored, or sent anywhere.
const STATUS_MAX_CHARS = 30;

// Returns the text to show, or null when the message is not a valid status message.
// Text longer than STATUS_MAX_CHARS is cut and ends with "..".
function parseStatusMessage(message) {
    if (!(message instanceof Lang.Dictionary)) {
        return null;
    }
    if (!message.hasKey("v") || !message.hasKey("type") || !message.hasKey("text")) {
        return null;
    }
    if (!(message["v"] instanceof Lang.Number) || message["v"] != 1) {
        return null;
    }
    if (!(message["type"] instanceof Lang.String) || !message["type"].equals("status")) {
        return null;
    }
    var text = message["text"];
    if (!(text instanceof Lang.String) || text.length() == 0) {
        return null;
    }
    if (text.length() > STATUS_MAX_CHARS) {
        return text.substring(0, STATUS_MAX_CHARS - 2) + "..";
    }
    return text;
}

// The full Claude page (page 2). Optional fields of the same status message:
//   "title": "Claude"            up to 12 characters
//   "ctx":   59                  context used, percent 0..100 (anything else is ignored)
//   "lines": ["pulse", "Opus 5.5", "rb ba2d0b1a", "14:25"]   up to 4 lines, 22 characters each
// Returns { "title" => String, "ctx" => Number or null, "lines" => Array<String> } or null
// when the message is not a valid status message.
const STATUS_PAGE_LINES = 4;
const STATUS_PAGE_LINE_CHARS = 22;

function parseStatusPage(raw) {
    if (parseStatusMessage(raw) == null) {
        return null;
    }
    var message = raw as Lang.Dictionary;
    var title = "Claude";
    if (message.hasKey("title") && message["title"] instanceof Lang.String && message["title"].length() > 0) {
        title = cutText(message["title"], 12);
    }
    var ctx = null;
    if (message.hasKey("ctx") && message["ctx"] instanceof Lang.Number
            && message["ctx"] >= 0 && message["ctx"] <= 100) {
        ctx = message["ctx"];
    }
    var lines = [];
    if (message.hasKey("lines") && message["lines"] instanceof Lang.Array) {
        var source = message["lines"] as Lang.Array;
        for (var i = 0; i < source.size() && lines.size() < STATUS_PAGE_LINES; i += 1) {
            if (source[i] instanceof Lang.String && source[i].length() > 0) {
                lines.add(cutText(source[i], STATUS_PAGE_LINE_CHARS));
            }
        }
    }
    if (lines.size() == 0) {
        lines.add(parseStatusMessage(message));
    }
    return { "title" => title, "ctx" => ctx, "lines" => lines };
}

function cutText(text as Lang.String, maxChars as Lang.Number) as Lang.String {
    if (text.length() <= maxChars) {
        return text;
    }
    return text.substring(0, maxChars - 2) + "..";
}
