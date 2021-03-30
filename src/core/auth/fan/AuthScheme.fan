//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   26 Apr 16  Brian Frank  Creation
//

using concurrent
using web

**
** AuthScheme is base class for modeling pluggable authentication algorithms
**
abstract const class AuthScheme
{

//////////////////////////////////////////////////////////////////////////
// Registry
//////////////////////////////////////////////////////////////////////////

  ** Schemes registerd in the system
  static AuthScheme[] list()
  {
    registry.list
  }

  ** Lookup a AuthScheme type for the given case insensitive name.
  static AuthScheme? find(Str name, Bool checked := true)
  {
    registry.find(name, checked)
  }

  ** Registry
  private static AuthSchemeRegistry registry()
  {
    r := registryRef.val as AuthSchemeRegistry
    if (r == null) registryRef.val = r = AuthSchemeRegistry()
    return r
  }
  private static const AtomicRef registryRef := AtomicRef()

  ** Subclass constructor
  protected new make(Str name)
  {
    if (name != name.lower) throw ArgErr("Name must be lowercase: $name")
    this.name = name
  }

//////////////////////////////////////////////////////////////////////////
// Overrides
//////////////////////////////////////////////////////////////////////////

  ** Scheme name (always normalized to lowercase)
  const Str name

  ** Handle a server authentation message from a client.  If its
  ** the initial message, then 'msg.scheme' will be "hello".  There
  ** are three outcomes:
  **   1. If the client should be challenged with a 401, then return
  **      the message to send in the WWW-Authenticate header
  **   2. If the client has been successfully authenticated then
  **      return a message with the 'authToken' parameter in the
  **      Authentication-Info header.  The authToken should be
  **      generated via `AuthServerContext.login`
  **   3. If authentication fails, then raise `AuthErr`
  abstract AuthMsg onServer(AuthServerContext cx, AuthMsg msg)

  ** Handle a standarized client authentation challenge message from
  ** the server using RFC 7235.  Return the message to send back
  ** to the server to authenticate.
  abstract AuthMsg onClient(AuthClientContext cx, AuthMsg msg)

  ** Callback after successful authentication to process the
  ** Authentication-Info bearer token header parameters.
  virtual Void onClientSuccess(AuthClientContext cx, AuthMsg msg) {}

  ** Handle non-standardized client authentication when the standard
  ** process fails.  If this scheme thinks it can handle the given
  ** WebClient's response by sniffing the response code and headers
  ** then it should process and return true.
  virtual Bool onClientNonStd(AuthClientContext cx, WebClient c, Str? content) { false }

}

**************************************************************************
** AuthSchemeRegistry
**************************************************************************

**
** AuthSchemeRegistry loaded from 'auth.scheme' indexed prop
**
internal const class AuthSchemeRegistry
{
  new make()
  {
    list := AuthScheme[,]
    byName := Str:AuthScheme[:]
    try
    {
      Env.cur.index("auth.scheme").each |qname|
      {
        try
        {
          scheme := (AuthScheme)Type.find(qname).make
          byName.add(scheme.name, scheme)
          list.add(scheme)
        }
        catch (Err e) echo("ERROR: Invalid auth.scheme: $qname; $e")
      }
      list = list.sort |a, b| { a.name <=> b.name }
    }
    catch (Err e) e.trace
    this.list = list
    this.byName = byName
  }

  const AuthScheme[] list

  const Str:AuthScheme byName

  AuthScheme? find(Str name, Bool checked := true)
  {
    scheme := byName[name.lower]
    if (scheme != null) return scheme
    if (checked) throw Err("Unknown auth scheme: $name")
    return null
  }
}