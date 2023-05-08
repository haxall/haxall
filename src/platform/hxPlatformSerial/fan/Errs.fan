//
// Copyright (c) 2016, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Jun 2016  Brian Frank      Creation
//  20 Jan 2022  Matthew Giannini Redesign for Haxall
//

using haystack

@NoDoc const class UnknownSerialPortErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

@NoDoc const class SerialPortAlreadyOpenErr : Err
{
  new make(Str msg, Err? cause := null) : super(msg, cause) {}
}

