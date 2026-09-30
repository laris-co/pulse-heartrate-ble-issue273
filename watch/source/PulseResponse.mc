using Toybox.Lang as Lang;

function buildPulseResponse(nonce as Lang.String, bpm as Lang.Number, ageMs as Lang.Number) as Lang.Dictionary {
    return {
        "v" => 1,
        "type" => "pulse",
        "nonce" => nonce,
        "bpm" => bpm,
        "ageMs" => ageMs
    };
}
