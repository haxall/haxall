//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Apr 16  Brian Frank  Creation
//

using web

**
** AuthMsg models a scheme name and set of parameters according
** to [RFC 7235]`https://tools.ietf.org/html/rfc7235`.  To simplify
** parsing, we restrict the grammar to be auth-param and token (the
** token68 and quoted-string productions are not allowed).
**
@Js
const class AuthMsg
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Parse a list of AuthSchemes such as a list of 'challenge'
  ** productions for the WWW-Authentication header per RFC 7235.
  static AuthMsg[] listFromStr(Str s)
  {
    splitList(s).map |tok->AuthMsg| { fromStr(tok) }
  }

  ** Parse a string encoding according to RFC 7235.
  static new fromStr(Str s, Bool checked := true)
  {
    try
    {
      return decode(s)
    }
    catch (Err e)
    {
      if (checked) throw ParseErr(e.toStr)
      return null
    }
  }

  ** Constructor
  new make(Str scheme, Str:Str params)
  {
    this.scheme = scheme.lower
    this.params = params
    this.toStr  = encode(scheme, params)
  }

//////////////////////////////////////////////////////////////////////////
// Identity
//////////////////////////////////////////////////////////////////////////

  ** Scheme name normalized to lowercase
  const Str scheme

  ** Parameters for scheme
  const Str:Str params

  ** Str encoding per RFC 7235
  const override Str toStr

  ** Hash code is based on string encoding
  override Int hash() { toStr.hash }

  ** Equality is based on string encoding
  override Bool equals(Obj? that)
  {
    that is AuthMsg && toStr == that.toStr
  }

  ** Lookup a parameter by name
  Str? param(Str name, Bool checked := true)
  {
    val := params[name]
    if (val != null) return val
    if (checked) throw Err("AuthScheme param not found: $name")
    return null
  }

  ** Get the encoded parameters without the scheme name prefix
  Str paramsToStr()
  {
    if (params.isEmpty) return ""
    return toStr[toStr.index(" ")+1..-1]
  }

//////////////////////////////////////////////////////////////////////////
// Encoding
//////////////////////////////////////////////////////////////////////////

  ** This utility parses a list of challenge productions from RFC 7235
  ** which can then be parsed as individual AuthScheme instances.  The
  ** grammar is extremely confusing because we have to look at comma split
  ** tokens and determine if its a "name" or "name key=val" start of a new
  ** challenge.
  internal static Str[] splitList(Str s)
  {
    // find break indices (start of each challenge production)
    toks := s.split(',')
    breaks := Int[,]
    s.split(',').each |tok, i|
    {
      sp := tok.index(" ")
      name := sp == null ? tok : tok[0..<sp]
      if (WebUtil.isToken(name) && i > 0) breaks.add(i)
    }

    // rejoin tokens into challenge strings
    acc := Str[,]
    start := 0
    breaks.each |end|
    {
      acc.add(toks[start..<end].join(","))
      start = end
    }
    acc.add(toks[start..-1].join(","))
    return acc
  }

  private static AuthMsg decode(Str s)
  {
    sp := s.index(" ")
    scheme := s
    params := Str:Str[:] { caseInsensitive = true }
    if (sp != null)
    {
      scheme = s[0..<sp]
      s[sp+1..-1].split(',').each |p|
      {
        eq := p.index("=") ?: throw Err("Invalid auth-param: $p")
        params[p[0..<eq].trim] = p[eq+1..-1].trim
      }
    }
    return AuthMsg(scheme, params)
  }

  private static Str encode(Str scheme, Str:Str params)
  {
    s := StrBuf()
    addToken(s, scheme)
    first := true
    params.keys.sort.each |n|
    {
      v := params[n]
      if (first) first = false
      else s.addChar(',')
      s.addChar(' '); addToken(s, n); s.addChar('='); addToken(s, v)
    }
    return s.toStr
  }

  private static Void addToken(StrBuf buf, Str val)
  {
    for (i := 0; i<val.size; ++i)
    {
      c := val[i]
      if (WebUtil.isTokenChar(c))
        buf.addChar(c)
      else
        throw Err("Invalid char '$c.toChar' in $val.toCode")
    }
  }
}