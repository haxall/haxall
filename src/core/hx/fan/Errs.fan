//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jul 2021  Brian Frank  Creation
//

** Unknown project
@NoDoc const class UnknownProjErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

** Unknown extension
@NoDoc @Js const class UnknownExtErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

** Unknown message received
@NoDoc const class UnknownMsgErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

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

** Thrown by Context.session when not in a session
@NoDoc const class SessionUnavailableErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}


** Thrown when trying to uninstall a boot lib
@NoDoc const class CannotRemoveBootLibErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

