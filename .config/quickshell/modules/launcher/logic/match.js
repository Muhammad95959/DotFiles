.pragma library

function shQuote(s) {
  return "'" + String(s).replace(/'/g, "'\\''") + "'";
}

function toksOf(s) {
  return String(s || "").toLowerCase().trim().split(/\s+/).filter(function (t) { return t.length > 0; });
}

function matches(hay, toks) {
  var h = String(hay || "").toLowerCase();
  for (var i = 0; i < toks.length; i++)
    if (!h.includes(toks[i]))
      return false;
  return true;
}
