//
// Copyright (c) 2020, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   08 Jun 20  Matthew Giannini  Creation
//   27 Jan 22  Matthew Giannini  Port to Haxall
//


using web

const class OAuthErr : Err
{
  new make(WebClient c)  : super(c.resPhrase)
  {
    this.code = c.resCode
    this.body = c.resStr
  }

  const Int code
  const Str body

  override Str toStr() { "[$code] ${super.msg}\n$body" }
}