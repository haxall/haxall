//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Jun 2018  Brian Frank  Creation
//

** CompilerErr
@NoDoc const class CompilerErr : Err
{
  new make(Str msg, CLoc loc, Err? cause) : super(msg, cause) { this.loc = loc }
  const CLoc loc
}

** UnresolvedDocLinkErr
@NoDoc const class UnresolvedDocLinkErr : Err
{
  new make(Str link) : super(link, cause) {}
}

