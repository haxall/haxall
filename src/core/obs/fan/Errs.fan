//
// Copyright (c) 2020, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Apr 2020  Brian Frank  COVID-19!
//

** Observable not found
@NoDoc
const class UnknownObservableErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

** Observable subscription not found
@NoDoc
const class UnknownSubscriptionErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}




