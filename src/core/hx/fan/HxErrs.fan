//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jul 2021  Brian Frank  Creation
//

** Unknown watch
@NoDoc const class UnknownWatchErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

** Watch closed
@NoDoc const class WatchClosedErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

** Thrown by HxContext.session when not in a session
@NoDoc const class SessionUnavailableErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

