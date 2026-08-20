//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   30 Jul 2026  Brian Frank  Creation
//

**
** Protocol version of the Xeto HTTP API as passed in the Xeto-Version
** header.  On the wire a version is the `sys.api::ApiVersion` scalar
** token, which is currently the decimal number but is treated as an
** opaque string so the format stays open to future revisions.
**
@Js @NoDoc
enum class ApiVersion
{
  ** Version 4 legacy pre-xeto protocol
  v4("4"),

  ** Version 5 xeto protocol
  v5("5")

  private new make(Str token) { this.token = token }

  ** Wire token used in the Xeto-Version header
  const Str token

  ** Version assumed when the Xeto-Version header is undefined
  static const ApiVersion def := v4

  ** Latest version supported by this server
  static const ApiVersion cur := v5

  ** Tokens for all supported versions
  static const Str[] tokens := ApiVersion.vals.map |v->Str| { v.token }.toImmutable

  ** Decode from wire token or return null/raise if not supported
  static ApiVersion? fromToken(Str? token, Bool checked := true)
  {
    if (token == "4") return v4
    if (token == "5") return v5
    if (checked) throw ParseErr("ApiVersion: $token")
    return null
  }

  ** Is the v4 constant
  Bool isV4() { this === v4 }

  ** Is the v5 constant
  Bool isV5() { this === v5 }
}

