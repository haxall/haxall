//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Jan 2016  Matthew Giannini Creation
//

"use strict";

var hxLogin = {};

// fields set by HxUserWeb
hxLogin.authUri = null;
hxLogin.redirectUri = null;
hxLogin.localeLogin = "Login";
hxLogin.localeLoggingIn = "Logging in";
hxLogin.localeBadCreds = "Invalid username or password"

hxLogin.init = function()
{
  document.getElementById("err").style.display = "none";
  document.getElementById("username").focus();
}

hxLogin.authReq = function(reqHeaders, func)
{
  var xhr = new XMLHttpRequest();
  xhr.open("GET", hxLogin.authUri, true);
  Object.keys(reqHeaders).forEach(function (key) {
    xhr.setRequestHeader(key, reqHeaders[key]);
  });
  xhr.onreadystatechange = function(event)
  {
    if (xhr.readyState == 4) func(xhr.status, xhr);
  }
  xhr.send();
}

hxLogin.str2b64uriUtf8 = function(s)
{
  // convert the given string to utf8, then base64 encode it
  var crypto = hxLogin.crypto;
  return crypto.rstr2b64uri(crypto.str2rstr_utf8(s));
}

hxLogin.toQuotedStr = function(s)
{
  return '"' + s.replace('"', '\\"') + '"';
}

hxLogin.parseWwwAuth = function(xhr)
{
  var wwwAuth = xhr.getResponseHeader("WWW-Authenticate");
  var parser = new hxLogin.AuthParser(wwwAuth);
  return parser.nextScheme();
}

hxLogin.loginAuth = function()
{
  // short-cut crypto namespace
  var crypto = hxLogin.crypto;

  // disable login button
  hxLogin.loginStart();

  // get username/password input
  var username = document.getElementById("username").value;
  var password = document.getElementById("password").value;
  var u64 = hxLogin.str2b64uriUtf8(username);

  // hello
  hxLogin.authReq({"Authorization": 'HELLO username='+u64+''}, function (code, xhr) {
    if (code == 200)
    {
      hxLogin.onSuccess(xhr);
      return;
    }
    if (code != 401)
    {
      console.log("ERROR: HELLO failed: " + code);
      hxLogin.onFail(hxLogin.failReason(xhr));
      return;
    }

    var scheme = hxLogin.parseWwwAuth(xhr);
    try
    {
      if ("scram" == scheme.name.toLowerCase())
        hxLogin.scram(username, password, scheme);
      else if ("plaintext" == scheme.name.toLowerCase())
        hxLogin.plaintext(username, password, scheme);
      else
        throw "Unsupported auth scheme: " + scheme.name;
    }
    catch (e)
    {
      console.log(e);
      hxLogin.onFail("check javascript console");
    }
  });

  return false;
}

hxLogin.plaintext = function(username, password, hello)
{
  var crypto = hxLogin.crypto;
  var header = hello.name +
    " username=" + crypto.rstr2b64uri(username) +
    ", password=" + crypto.rstr2b64uri(password);
  hxLogin.authReq({"Authorization": header},
    function (code, xhr) {
      if (code != 200) {
        hxLogin.onFail(hxLogin.failReason(xhr));
      } else {
        hxLogin.onSuccess(xhr);
      }
    });
}

hxLogin.scram = function(username, password, hello)
{
  var crypto   = hxLogin.crypto;
  var hashSpec = hxLogin.hashSpec(hello.param("hash"));
  var hash     = hashSpec["hash"];
  var keyBits  = hashSpec["bits"];

  var gs2_header = "n,,";
  var c_nonce    = crypto.nonce(24);
  var c1_bare    = "n=" + username + ",r=" + c_nonce;
  var c1_msg     = gs2_header + c1_bare;
  var c1_data    = crypto.rstr2b64uri(c1_msg);

  var decode = function(s) {
    var data = {};
    s.split(',').forEach(function (tok) {
      var n = tok.indexOf('=');
      if (n > 0) {
        data[tok.substring(0, n)] = tok.substring(n+1);
      }
    });
    return data;
  };

  var doFinal = function(scheme1) {
    var s1_msg = window.atob(scheme1.param("data"));
    var s1Data = decode(s1_msg);

    var cbind_input     = gs2_header;
    var channel_binding = "c=" + crypto.rstr2b64(cbind_input);
    var nonce           = "r=" + s1Data["r"];
    var c2_no_proof     = channel_binding + "," + nonce;

    // construct proof
    var salt           = window.atob(s1Data["s"]);
    var iterations     = parseInt(s1Data["i"]);
    var saltedPassword = crypto.pbkdf2_hmac_sha256(password, salt, iterations, keyBits/8);
    var clientKey      = hash("Client Key", saltedPassword);
    var storedKey      = hash(clientKey);
    var authMsg        = c1_bare + "," + s1_msg + "," + c2_no_proof;
    var clientSig      = hash(authMsg, storedKey);

    var proof   = crypto.rstr2b64(crypto.xor(clientKey, clientSig));
    var c2_msg  = c2_no_proof + ",p=" + proof;
    var c2_data = crypto.rstr2b64uri(c2_msg);
    var header  = '' + hello.name + ' data=' + c2_data;
    var tok     = scheme1.param("handshakeToken");
    if (tok != null) header += ", handshakeToken=" + tok;
    hxLogin.authReq({"Authorization": header },
      function (code, xhr) {
        if (code != 200) {
          hxLogin.onFail(hxLogin.failReason(xhr));
        }
        else {
          hxLogin.onSuccess(xhr);
        }
      });
  };

  var header = hello.name + " data=" + c1_data;
  var tok    = hello.param("handshakeToken");
  if (tok != null) header += ", handshakeToken=" + tok;
  hxLogin.authReq({"Authorization": header },
    function (code, xhr) {
      if (code != 401) {
        hxLogin.onFail(hxLogin.failReason(xhr));
      }
      else {
        doFinal(hxLogin.parseWwwAuth(xhr));
      }
    });
}

hxLogin.onSuccess = function(xhr)
{
  // login ok, redirect to uri
  window.location = hxLogin.redirectUri;
}

hxLogin.onFail = function(msg)
{
  // login error
  var err = document.getElementById("err");
  err.style.display = "block";
  err.classList.add("on");

  if (msg != null) err.innerText = msg;
  hxLogin.loginEnd();
}

hxLogin.failReason = function(xhr)
{
  var err = xhr.getResponseHeader("x-hx-login-err");
  if (err == null) err = hxLogin.localeBadCreds;
  return err;
}

hxLogin.loginStart = function()
{
  var button = document.getElementById("loginButton");
  button.disabled = true;
  button.value = hxLogin.localeLoggingIn;
}

hxLogin.loginEnd = function()
{
  var button = document.getElementById("loginButton");
  button.disabled = false;
  button.value = hxLogin.localeLogin;
  document.getElementById("username").focus();
}

hxLogin.hashSpec = function(hashFunc) {
  var crypto = hxLogin.crypto;
  var spec   = {};
  switch (hashFunc.toLowerCase())
  {
    case "sha-1":   spec["hash"] = crypto.sha1;   spec["bits"] = 160; break;
    case "sha-256": spec["hash"] = crypto.sha256; spec["bits"] = 256; break;
    default: throw "Unsupported hashFunc: " + hashFunc;
  }
  return spec;
}

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  */

hxLogin.AuthScheme = function()
{
  this.name = null;
  this.params = {};
  this.param = function(name) {
    var val = null;
    var params = this.params;
    Object.keys(params).forEach(function (key) {
      if (key.toLowerCase() == name.toLowerCase()) val = params[key];
    });
    return val;
  };
}

hxLogin.AuthParser = function(header)
{
  this.buf  = header;
  this.pos  = -2;
  this.cur  = -1;
  this.peek = -1;
  this.reset(0);

  this.SP    = " ".charCodeAt(0);
  this.HTAB  = "\t".charCodeAt(0);
  this.COMMA = ",".charCodeAt(0);
  this.EQ    = "=".charCodeAt(0);
  this.DQUOT = '"'.charCodeAt(0);
  this.EOF   = -1;
}

hxLogin.AuthParser.prototype.nextScheme = function()
{
  if (this.eof()) return null;
  if (this.pos > 0) this.commaOws();

  var scheme = new hxLogin.AuthScheme();
  scheme.name = this.parseToken([this.SP, this.COMMA, this.EOF]).toLowerCase();
  if (this.cur != this.SP) return scheme;

  while (this.cur == this.SP) this.consume();

  scheme.params = this.parseAuthParams();
  return scheme;
}

hxLogin.AuthParser.prototype.parseToken = function(terms)
{
  var start = this.pos;
  while (true)
  {
    if (this.eof())
    {
      if (terms.indexOf(this.EOF) >= 0) break;
      throw "Unexpected <eof>: " + this.buf;
    }
    if (terms.indexOf(this.cur) >= 0) break;
    this.consume();
  }
  return this.buf.substring(start, this.pos);
}

hxLogin.AuthParser.prototype.parseAuthParams = function()
{
  var params = {};
  var start = this.pos;
  while (true)
  {
    start = this.pos;
    if (this.eof()) break;
    if (Object.keys(params).length > 0) this.commaOws();
    if (!this.parseAuthParam(params)) { this.reset(start); break; }
    this.ows();
  }
  return params;
}

hxLogin.AuthParser.prototype.parseAuthParam = function(params)
{
  if (this.eof()) return false;

  var start = this.pos;
  var key = this.parseToken([this.SP, this.HTAB, this.EQ, this.COMMA, this.EOF]).toLowerCase();
  this.ows();
  if (this.cur != this.EQ)
  {
    // backtrack
    this.reset(start);
    return false;
  }
  this.consume();
  this.ows();
  var val = this.cur == this.DQUOT ? this.parseQuotedString() : this.parseToken([this.SP, this.HTAB, this.COMMA, this.EOF]);
  this.ows();
  params[key] = val;
  return true;
}

hxLogin.AuthParser.prototype.parseQuotedString = function()
{
  var start = this.pos;
  if (this.cur != this.DQUOT) throw "Expected '\"' at pos " + this.pos;
  this.consume();
  while(true)
  {
    if (this.eof()) throw "Unterminated quoted-string starting at " + this.pos;
    if (this.cur == this.DQUOT) { this.consume(); break; }
    if (this.cur == this.ESC && this.peek == this.DQUOT) { this.consume(); this.consume(); }
    else this.consume();
  }
  var quoted = this.buf.substring(start, this.pos);
  if (quoted.length < 2 || quoted[0] != '"' || quoted[quoted.length-1] != '"')
    throw "Not a quoted string: " + quoted;
  return quoted.substring(1, quoted.length-1).replace("\\\"", '"');
}

hxLogin.AuthParser.prototype.commaOws = function()
{
  if (this.cur != this.COMMA) throw "Expected ',': " + buf.substring(0, this.pos);
  this.consume();
  this.ows();
}

hxLogin.AuthParser.prototype.ows = function()
{
  while(this.isOws()) this.consume();
}

hxLogin.AuthParser.prototype.isOws = function()
{
  return this.cur == this.SP || this.cur == this.HTAB;
}

hxLogin.AuthParser.prototype.reset = function(pos)
{
  this.pos = pos - 2;
  this.consume();
  this.consume();
}

hxLogin.AuthParser.prototype.consume = function()
{
  this.cur = this.peek;
  this.pos++;
  if (this.pos+1 < this.buf.length)
    this.peek = this.buf.charCodeAt(this.pos+1);
  else
    this.peek = -1;
  if (this.pos > this.buf.length) pos = this.buf.length;
}

hxLogin.AuthParser.prototype.eof = function()
{
  return this.cur == this.EOF;
}

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  */

/**
 * Crypto utils over raw strings where each char is one byte.  The hashes
 * are SHA-1 and SHA-256 (FIPS 180-4), HMAC (RFC 2104), and PBKDF2 (RFC 8018).
 */
hxLogin.crypto = (function () {

  var crypto = {};

  /** Base64 table */
  crypto.tab = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

  /** Random string of len base64 chars */
  crypto.nonce = function(len) {
    if (len == null) len = 24;
    var s = "";
    for (var i=0; i<len; ++i) s += crypto.tab.charAt(Math.floor(Math.random() * 64));
    return s;
  };

  /** XOR two raw strings of equal length */
  crypto.xor = function(a, b) {
    if (a.length != b.length) throw "Lengths don't match";
    var s = "";
    for (var i=0; i<a.length; ++i) s += String.fromCharCode((a.charCodeAt(i) ^ b.charCodeAt(i)) & 0xff);
    return s;
  };

  /** Encode raw string to base64 */
  crypto.rstr2b64 = function(s) { return window.btoa(toRstr(toBytes(s))); };

  /** Encode raw string to base64uri with no padding */
  crypto.rstr2b64uri = function(s) {
    return crypto.rstr2b64(s).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
  };

  /** Decode base64uri to raw string */
  crypto.b64uri2rstr = function(s) {
    return window.atob(s.replace(/-/g, "+").replace(/_/g, "/"));
  };

  /** Encode string as UTF-8 raw string */
  crypto.str2rstr_utf8 = function(s) { return toRstr(new TextEncoder().encode(s)); };

  /** SHA-1 of data, or HMAC-SHA1 if key defined; both UTF-8 encoded first */
  crypto.sha1 = function(data, key) {
    data = toBytes(crypto.str2rstr_utf8(data));
    if (key === undefined) return toRstr(sha1(data));
    return toRstr(mac(sha1, toBytes(crypto.str2rstr_utf8(key)))(data));
  };

  /** SHA-256 of raw string data, or HMAC-SHA256 if raw string key defined */
  crypto.sha256 = function(data, key) {
    data = toBytes(data);
    if (key === undefined) return toRstr(sha256(data));
    return toRstr(mac(sha256, toBytes(key))(data));
  };

  /** PBKDF2 with HMAC-SHA256 over raw strings */
  crypto.pbkdf2_hmac_sha256 = function(pass, salt, iterations, dkLen) {
    var prf = mac(sha256, toBytes(pass));
    var dk = [];
    for (var i=1; dk.length<dkLen; ++i) {
      var u = prf(toBytes(salt).concat([i >>> 24, (i >>> 16) & 0xff, (i >>> 8) & 0xff, i & 0xff]));
      var t = u.slice();
      for (var c=1; c<iterations; ++c) {
        u = prf(u);
        for (var j=0; j<t.length; ++j) t[j] ^= u[j];
      }
      dk = dk.concat(t);
    }
    return toRstr(dk.slice(0, dkLen));
  };

  function toBytes(s) {
    var b = new Array(s.length);
    for (var i=0; i<s.length; ++i) b[i] = s.charCodeAt(i) & 0xff;
    return b;
  }

  function toRstr(b) {
    var s = "";
    for (var i=0; i<b.length; ++i) s += String.fromCharCode(b[i]);
    return s;
  }

  function rotl(x, n) { return (x << n) | (x >>> (32 - n)); }
  function rotr(x, n) { return (x >>> n) | (x << (32 - n)); }

  // big-endian words of message padded with 0x80, zeros, and 64-bit bit length
  function padWords(b) {
    var n = b.length;
    var w = new Array(((((n + 8) >> 6) + 1) << 4)).fill(0);
    for (var i=0; i<n; ++i) w[i >> 2] |= b[i] << (24 - (i & 3) * 8);
    w[n >> 2] |= 0x80 << (24 - (n & 3) * 8);
    w[w.length-2] = Math.floor(n / 0x20000000);
    w[w.length-1] = (n * 8) | 0;
    return w;
  }

  function wordsToBytes(h) {
    var b = [];
    for (var i=0; i<h.length; ++i) b.push((h[i] >>> 24) & 0xff, (h[i] >>> 16) & 0xff, (h[i] >>> 8) & 0xff, h[i] & 0xff);
    return b;
  }

  function sha1(bytes) {
    var m = padWords(bytes);
    var h = [0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0];
    var w = new Array(80);
    for (var off=0; off<m.length; off+=16) {
      for (var t=0; t<16; ++t) w[t] = m[off + t];
      for (var t=16; t<80; ++t) w[t] = rotl(w[t-3] ^ w[t-8] ^ w[t-14] ^ w[t-16], 1);
      var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4];
      for (var t=0; t<80; ++t) {
        var f, k;
        if (t < 20)      { f = (b & c) | (~b & d);          k = 0x5a827999; }
        else if (t < 40) { f = b ^ c ^ d;                   k = 0x6ed9eba1; }
        else if (t < 60) { f = (b & c) | (b & d) | (c & d); k = 0x8f1bbcdc; }
        else             { f = b ^ c ^ d;                   k = 0xca62c1d6; }
        var tmp = (rotl(a, 5) + f + e + k + w[t]) | 0;
        e = d; d = c; c = rotl(b, 30); b = a; a = tmp;
      }
      h[0] = (h[0] + a) | 0;
      h[1] = (h[1] + b) | 0;
      h[2] = (h[2] + c) | 0;
      h[3] = (h[3] + d) | 0;
      h[4] = (h[4] + e) | 0;
    }
    return wordsToBytes(h);
  }

  // first 32 bits of fractional part of cube roots of first 64 primes
  var sha256K = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
  ];

  function sha256(bytes) {
    var m = padWords(bytes);
    // first 32 bits of fractional part of square roots of first 8 primes
    var h = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];
    var w = new Array(64);
    for (var off=0; off<m.length; off+=16) {
      for (var t=0; t<16; ++t) w[t] = m[off + t];
      for (var t=16; t<64; ++t) {
        var x = w[t-15], y = w[t-2];
        w[t] = (w[t-16] + (rotr(x, 7) ^ rotr(x, 18) ^ (x >>> 3)) + w[t-7] + (rotr(y, 17) ^ rotr(y, 19) ^ (y >>> 10))) | 0;
      }
      var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
      for (var t=0; t<64; ++t) {
        var t1 = (hh + (rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25)) + ((e & f) ^ (~e & g)) + sha256K[t] + w[t]) | 0;
        var t2 = ((rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22)) + ((a & b) ^ (a & c) ^ (b & c))) | 0;
        hh = g; g = f; f = e; e = (d + t1) | 0;
        d = c; c = b; b = a; a = (t1 + t2) | 0;
      }
      h[0] = (h[0] + a) | 0;
      h[1] = (h[1] + b) | 0;
      h[2] = (h[2] + c) | 0;
      h[3] = (h[3] + d) | 0;
      h[4] = (h[4] + e) | 0;
      h[5] = (h[5] + f) | 0;
      h[6] = (h[6] + g) | 0;
      h[7] = (h[7] + hh) | 0;
    }
    return wordsToBytes(h);
  }

  // return function computing HMAC of data bytes for 64 byte block hash
  function mac(hash, key) {
    if (key.length > 64) key = hash(key);
    var ipad = [], opad = [];
    for (var i=0; i<64; ++i) {
      var b = i < key.length ? key[i] : 0;
      ipad.push(b ^ 0x36);
      opad.push(b ^ 0x5c);
    }
    return function(data) { return hash(opad.concat(hash(ipad.concat(data)))); };
  }

  return crypto;

})();
