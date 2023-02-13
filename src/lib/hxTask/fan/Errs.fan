//
// Copyright (c) 2020, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   6 Apr 2020  Brian Frank  COVID-19!
//

@NoDoc
const class UnknownTaskErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

@NoDoc
const class NotTaskContextErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

@NoDoc
const class TaskFaultErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

@NoDoc
const class TaskDisabledErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

@NoDoc
const class TaskEphemeralErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

@NoDoc
const class TaskKilledErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}