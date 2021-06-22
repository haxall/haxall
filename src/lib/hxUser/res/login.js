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
      else if ("x-plaintext" == scheme.name.toLowerCase())
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

// Polyfill Object.keys and Array.prototype.forEach for IE11 on Windows 7
if (!Object.keys) {
  Object.keys = function(dict) {
    var arr = [];
    for (var key in dict) {
      if (dict.hasOwnProperty(key)) {
        arr.push(key);
      }
    }
    return arr;
  };
}

// Production steps of ECMA-262, Edition 5, 15.4.4.18
// Reference: http://es5.github.io/#x15.4.4.18
if (!Array.prototype.forEach) {

  Array.prototype.forEach = function(callback/*, thisArg*/) {
    var T, k;

    if (this == null) {
      throw new TypeError('this is null or not defined');
    }

    // 1. Let O be the result of calling toObject() passing the
    // |this| value as the argument.
    var O = Object(this);

    // 2. Let lenValue be the result of calling the Get() internal
    // method of O with the argument "length".
    // 3. Let len be toUint32(lenValue).
    var len = O.length >>> 0;

    // 4. If isCallable(callback) is false, throw a TypeError exception.
    // See: http://es5.github.com/#x9.11
    if (typeof callback !== 'function') {
      throw new TypeError(callback + ' is not a function');
    }

    // 5. If thisArg was supplied, let T be thisArg; else let
    // T be undefined.
    if (arguments.length > 1) {
      T = arguments[1];
    }

    // 6. Let k be 0.
    k = 0;

    // 7. Repeat while k < len.
    while (k < len) {

      var kValue;

      // a. Let Pk be ToString(k).
      //    This is implicit for LHS operands of the in operator.
      // b. Let kPresent be the result of calling the HasProperty
      //    internal method of O with argument Pk.
      //    This step can be combined with c.
      // c. If kPresent is true, then
      if (k in O) {

        // i. Let kValue be the result of calling the Get internal
        // method of O with argument Pk.
        kValue = O[k];

        // ii. Call the Call internal method of callback with T as
        // the this value and argument list containing kValue, k, and O.
        callback.call(T, kValue, k, O);
      }
      // d. Increase k by 1.
      k++;
    }
    // 8. return undefined.
  };
}
/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  */

/**
 * Common crypto utils
 */
hxLogin.crypto = (function () {

  var crypto = {};

  /** Base64 table */
  crypto.tab = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

  crypto.nonce = function(len) {
    if (len == null) len = 24;
    var text = "";
    var possible = crypto.tab;
    for(var i = 0; i < len; i++) {
        text += possible.charAt(Math.floor(Math.random() * possible.length));
    }
    return text;
  };

  /** calculate xor of two raw strings. The result is a raw string. */
  crypto.xor = function(a, b)
  {
    var aw = crypto.rstr2binb(a);
    var bw = crypto.rstr2binb(b);
    if (aw.length != bw.length) throw "Lengths don't match";
    for (var i = 0; i < aw.length; ++i) {
      aw[i] ^= bw[i];
    }
    return crypto.binb2rstr(aw);
  }

  /*
   * Convert a raw string to a hex string
   */
  crypto.rstr2hex = function(input)
  {
    var hexcase = 0;
    var hex_tab = hexcase ? "0123456789ABCDEF" : "0123456789abcdef";
    var output = "";
    var x;
    for(var i = 0; i < input.length; i++)
    {
      x = input.charCodeAt(i);
      output += hex_tab.charAt((x >>> 4) & 0x0F)
             +  hex_tab.charAt( x        & 0x0F);
    }
    return output;
  }

  /*
   * Convert a raw string to a base-64 string
   */
  crypto.rstr2b64 = function(input)
  {
    var b64pad = "=";
    var tab = crypto.tab; //"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    var output = "";
    var len = input.length;
    for(var i = 0; i < len; i += 3)
    {
      var triplet = (input.charCodeAt(i) << 16)
                  | (i + 1 < len ? input.charCodeAt(i+1) << 8 : 0)
                  | (i + 2 < len ? input.charCodeAt(i+2)      : 0);
      for(var j = 0; j < 4; j++)
      {
        if(i * 8 + j * 6 > input.length * 8) output += b64pad;
        else output += tab.charAt((triplet >>> 6*(3-j)) & 0x3F);
      }
    }
    return output;
  }

  /*
   * Convert a raw string to base64uri with no padding
   */
  crypto.rstr2b64uri = function(input)
  {
    return crypto.rstr2b64(input)
      .replace(/=/g, '')
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
  }

  /*
   * Decode a base64uri to a raw string.
   */
  crypto.b64uri2rstr = function(input)
  {
    return window.atob(input.replace(/\-/g, "+").replace(/_/g, "/"));
  }

  /*
   * Encode a string as utf-8.
   * For efficiency, this assumes the input is valid utf-16.
   */
  crypto.str2rstr_utf8 = function(input) {
    return unescape(encodeURIComponent(input));
  }

  /*
   * Convert a raw string to an array of big-endian words
   * Characters >255 have their high-byte silently ignored.
   */
  crypto.rstr2binb = function(input)
  {
    var output = Array(input.length >> 2);
    for(var i = 0; i < output.length; i++)
      output[i] = 0;
    for(var i = 0; i < input.length * 8; i += 8)
      output[i>>5] |= (input.charCodeAt(i / 8) & 0xFF) << (24 - i % 32);
    return output;
  }

  /*
   * Convert an array of big-endian words to a string
   */
  crypto.binb2rstr = function(input)
  {
    var output = "";
    for(var i = 0; i < input.length * 32; i += 8)
      output += String.fromCharCode((input[i>>5] >>> (24 - i % 32)) & 0xFF);
    return output;
  }

  return crypto;

})();

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  */

(function () {

  // crypto shortcut
  var crypto = hxLogin.crypto;

  /*
   * Main sha256 function, with its support functions
   */
  function sha256_S (X, n) {return ( X >>> n ) | (X << (32 - n));}
  function sha256_R (X, n) {return ( X >>> n );}
  function sha256_Ch(x, y, z) {return ((x & y) ^ ((~x) & z));}
  function sha256_Maj(x, y, z) {return ((x & y) ^ (x & z) ^ (y & z));}
  function sha256_Sigma0256(x) {return (sha256_S(x, 2) ^ sha256_S(x, 13) ^ sha256_S(x, 22));}
  function sha256_Sigma1256(x) {return (sha256_S(x, 6) ^ sha256_S(x, 11) ^ sha256_S(x, 25));}
  function sha256_Gamma0256(x) {return (sha256_S(x, 7) ^ sha256_S(x, 18) ^ sha256_R(x, 3));}
  function sha256_Gamma1256(x) {return (sha256_S(x, 17) ^ sha256_S(x, 19) ^ sha256_R(x, 10));}
  function sha256_Sigma0512(x) {return (sha256_S(x, 28) ^ sha256_S(x, 34) ^ sha256_S(x, 39));}
  function sha256_Sigma1512(x) {return (sha256_S(x, 14) ^ sha256_S(x, 18) ^ sha256_S(x, 41));}
  function sha256_Gamma0512(x) {return (sha256_S(x, 1)  ^ sha256_S(x, 8) ^ sha256_R(x, 7));}
  function sha256_Gamma1512(x) {return (sha256_S(x, 19) ^ sha256_S(x, 61) ^ sha256_R(x, 6));}

  var sha256_K = new Array
  (
    1116352408, 1899447441, -1245643825, -373957723, 961987163, 1508970993,
    -1841331548, -1424204075, -670586216, 310598401, 607225278, 1426881987,
    1925078388, -2132889090, -1680079193, -1046744716, -459576895, -272742522,
    264347078, 604807628, 770255983, 1249150122, 1555081692, 1996064986,
    -1740746414, -1473132947, -1341970488, -1084653625, -958395405, -710438585,
    113926993, 338241895, 666307205, 773529912, 1294757372, 1396182291,
    1695183700, 1986661051, -2117940946, -1838011259, -1564481375, -1474664885,
    -1035236496, -949202525, -778901479, -694614492, -200395387, 275423344,
    430227734, 506948616, 659060556, 883997877, 958139571, 1322822218,
    1537002063, 1747873779, 1955562222, 2024104815, -2067236844, -1933114872,
    -1866530822, -1538233109, -1090935817, -965641998
  );

  function binb_sha256(m, l)
  {
    var HASH = new Array(1779033703, -1150833019, 1013904242, -1521486534,
                         1359893119, -1694144372, 528734635, 1541459225);
    var W = new Array(64);
    var a, b, c, d, e, f, g, h;
    var i, j, T1, T2;

    /* append padding */
    m[l >> 5] |= 0x80 << (24 - l % 32);
    m[((l + 64 >> 9) << 4) + 15] = l;

    for(i = 0; i < m.length; i += 16)
    {
      a = HASH[0];
      b = HASH[1];
      c = HASH[2];
      d = HASH[3];
      e = HASH[4];
      f = HASH[5];
      g = HASH[6];
      h = HASH[7];

      for(j = 0; j < 64; j++)
      {
        if (j < 16) W[j] = m[j + i];
        else W[j] = safe_add(safe_add(safe_add(sha256_Gamma1256(W[j - 2]), W[j - 7]),
                                              sha256_Gamma0256(W[j - 15])), W[j - 16]);

        T1 = safe_add(safe_add(safe_add(safe_add(h, sha256_Sigma1256(e)), sha256_Ch(e, f, g)),
                                                            sha256_K[j]), W[j]);
        T2 = safe_add(sha256_Sigma0256(a), sha256_Maj(a, b, c));
        h = g;
        g = f;
        f = e;
        e = safe_add(d, T1);
        d = c;
        c = b;
        b = a;
        a = safe_add(T1, T2);
      }

      HASH[0] = safe_add(a, HASH[0]);
      HASH[1] = safe_add(b, HASH[1]);
      HASH[2] = safe_add(c, HASH[2]);
      HASH[3] = safe_add(d, HASH[3]);
      HASH[4] = safe_add(e, HASH[4]);
      HASH[5] = safe_add(f, HASH[5]);
      HASH[6] = safe_add(g, HASH[6]);
      HASH[7] = safe_add(h, HASH[7]);
    }
    return HASH;
  }

  function safe_add (x, y)
  {
    var lsw = (x & 0xFFFF) + (y & 0xFFFF);
    var msw = (x >> 16) + (y >> 16) + (lsw >> 16);
    return (msw << 16) | (lsw & 0xFFFF);
  }

  /*
   * Calculate the SHA256 of a raw string
   */
  function rstr_sha256(s)
  {
    return crypto.binb2rstr(binb_sha256(crypto.rstr2binb(s), s.length * 8));
  }

  /*
   * Calculate the HMAC-SHA256 of a key and some data (raw strings)
   */
  function rstr_hmac_sha256(key, data)
  {
    var bkey = crypto.rstr2binb(key);
    if(bkey.length > 16) bkey = crypto.binb_sha256(bkey, key.length * 8);

    var ipad = Array(16), opad = Array(16);
    for(var i = 0; i < 16; i++)
    {
      ipad[i] = bkey[i] ^ 0x36363636;
      opad[i] = bkey[i] ^ 0x5C5C5C5C;
    }

    var hash = binb_sha256(ipad.concat(crypto.rstr2binb(data)), 512 + data.length * 8);
    return crypto.binb2rstr(binb_sha256(opad.concat(hash), 512 + 256));
  }

  /**
   * Calculate the SHA256 hash of data if key is undefined. Otherwise,
   * calculate the HMAC-SHA-256 of the data using key.
   * @param {string} data - The data to hash. Must be a raw string.
   * @param {string} key - (optional) the key to use for HMAC.
   *  Must be a raw string.
   * @returns {string} - the hash as a raw string.
   */
  crypto.sha256 = function(data, key)
  {
    var hash;
    if (key === undefined) hash = rstr_sha256(data);
    else
    {
      hash = rstr_hmac_sha256(key, data);
    }
    return hash;
  }

  /**
   * Obtain a derived key using PBKDF2 with HMAC-SHA256 as the PRF.
   *
   * @param {string} key - The password to obtain a derived key for
   * @param {string} salt - The salt
   * @param {number} iterations - The number of iterations to apply
   * @param {number} dkLen - The desired length of the derived key in bytes
   * @returns {string} - The derived key. It is a raw string of dkLen bytes.
   */
  crypto.pbkdf2_hmac_sha256 = function(key, salt, iterations, dkLen)
  {
    var F = function F(P, S, c, i) {
      var U_r;
      var U_c;

      S = S + crypto.binb2rstr([i]);
      U_r = U_c = rstr_hmac_sha256(P, S);
      for (var iter = 1; iter < c; ++iter) {
        U_c = rstr_hmac_sha256(P, U_c);
        U_r = crypto.xor(U_r, U_c);
      }
      return U_r;
    };

    var hLen = 32; // sha256 output hash size in bytes
    var l = Math.ceil(dkLen / hLen);
    var r = dkLen - (l - 1) * hLen;
    var T = "";
    var block;

    for (var i = 1; i <= l; ++i) {
      block = F(key, salt, iterations, i);
      T += block;
    }

    return T.substr(0, dkLen)
  }

})();

/* - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -  */
(function () {

  // crypto shortcut
  var crypto = hxLogin.crypto;

  /*
   * Calculate the SHA-1 of an array of big-endian words, and a bit length
   */
  function binb_sha1(x, len)
  {
    /* append padding */
    x[len >> 5] |= 0x80 << (24 - len % 32);
    x[((len + 64 >> 9) << 4) + 15] = len;

    var w = Array(80);
    var a =  1732584193;
    var b = -271733879;
    var c = -1732584194;
    var d =  271733878;
    var e = -1009589776;

    for(var i = 0; i < x.length; i += 16)
    {
      var olda = a;
      var oldb = b;
      var oldc = c;
      var oldd = d;
      var olde = e;

      for(var j = 0; j < 80; j++)
      {
        if(j < 16) w[j] = x[i + j];
        else w[j] = bit_rol(w[j-3] ^ w[j-8] ^ w[j-14] ^ w[j-16], 1);
        var t = safe_add(safe_add(bit_rol(a, 5), sha1_ft(j, b, c, d)),
                         safe_add(safe_add(e, w[j]), sha1_kt(j)));
        e = d;
        d = c;
        c = bit_rol(b, 30);
        b = a;
        a = t;
      }

      a = safe_add(a, olda);
      b = safe_add(b, oldb);
      c = safe_add(c, oldc);
      d = safe_add(d, oldd);
      e = safe_add(e, olde);
    }
    return Array(a, b, c, d, e);

  }

  /*
   * Perform the appropriate triplet combination function for the current
   * iteration
   */
  function sha1_ft(t, b, c, d)
  {
    if(t < 20) return (b & c) | ((~b) & d);
    if(t < 40) return b ^ c ^ d;
    if(t < 60) return (b & c) | (b & d) | (c & d);
    return b ^ c ^ d;
  }

  /*
   * Determine the appropriate additive constant for the current iteration
   */
  function sha1_kt(t)
  {
    return (t < 20) ?  1518500249 : (t < 40) ?  1859775393 :
           (t < 60) ? -1894007588 : -899497514;
  }

  /*
   * Add integers, wrapping at 2^32. This uses 16-bit operations internally
   * to work around bugs in some JS interpreters.
   */
  function safe_add(x, y)
  {
    var lsw = (x & 0xFFFF) + (y & 0xFFFF);
    var msw = (x >> 16) + (y >> 16) + (lsw >> 16);
    return (msw << 16) | (lsw & 0xFFFF);
  }

  /*
   * Bitwise rotate a 32-bit number to the left.
   */
  function bit_rol(num, cnt)
  {
    return (num << cnt) | (num >>> (32 - cnt));
  }

  /*
   * Calculate the SHA-1 of a raw string
   */
  function rstr_sha1(s)
  {
    return crypto.binb2rstr(binb_sha1(crypto.rstr2binb(s), s.length * 8));
  }

  /*
   * Calculate the HMAC-SHA1 of a key and some data (raw strings)
   */
  function rstr_hmac_sha1(key, data)
  {
    var bkey = crypto.rstr2binb(key);
    if(bkey.length > 16) bkey = binb_sha1(bkey, key.length * 8);

    var ipad = Array(16), opad = Array(16);
    for(var i = 0; i < 16; i++)
    {
      ipad[i] = bkey[i] ^ 0x36363636;
      opad[i] = bkey[i] ^ 0x5C5C5C5C;
    }

    var hash = binb_sha1(ipad.concat(crypto.rstr2binb(data)), 512 + data.length * 8);
    return crypto.binb2rstr(binb_sha1(opad.concat(hash), 512 + 160));
  }

  /**
   * Calculate the SHA1 hash of data if key is undefined. Otherwise,
   * calculate the HMAC-SHA1 of the data using key. A raw string of
   * the hash is returned.
   */
  crypto.sha1 = function(data, key)
  {
    var hash;
    data = crypto.str2rstr_utf8(data);
    if (key === undefined) hash = rstr_sha1(data);
    else
    {
      key = crypto.str2rstr_utf8(key);
      hash = rstr_hmac_sha1(key, data);
    }
    return hash;
  }

})();