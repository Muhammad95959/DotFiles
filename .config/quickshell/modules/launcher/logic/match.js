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

// True when the text reads as Arabic rather than Latin. Counts script blocks
// instead of scanning codepoints so mixed text ("سوي Sofia") resolves correctly.
function isArabic(s) {
  var t = String(s || "");
  var arabic = 0;
  var latin = 0;
  for (var i = 0; i < t.length; i++) {
    var c = t.charCodeAt(i);
    if ((c >= 0x0600 && c <= 0x06ff) || (c >= 0x0750 && c <= 0x077f) || (c >= 0x08a0 && c <= 0x08ff) || (c >= 0xfb50 && c <= 0xfdff) || (c >= 0xfe70 && c <= 0xfeff))
      arabic++;
    else if ((c >= 0x41 && c <= 0x5a) || (c >= 0x61 && c <= 0x7a))
      latin++;
  }
  return arabic > latin;
}
