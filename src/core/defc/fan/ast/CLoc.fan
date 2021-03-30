//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Jun 2018  Brian Frank  Creation
//

using compilerDoc

**
** Source code location
**
const class CLoc : DocLoc
{
  ** None or unknown location
  static const CLoc none := make("unknown", 0)

  ** Compiler inputs
  static const CLoc inputs := make("inputs", 0)

  ** Constructor for file
  static new makeFile(File file)
  {
    uri := file.uri
    name := uri.scheme == "fan" ? "$uri.host::$uri.pathStr" : file.osPath
    return make(name)
  }

  ** Constructor
  new make(Str file, Int line := 0) : super(file, line) {}

}