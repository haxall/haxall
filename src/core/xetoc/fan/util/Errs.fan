//
// Copyright (c) 2023, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   10 Apr 2023  Brian Frank  Creation
//

using util

@Js
const class XetoCompilerErr : FileLocErr
{
  new make(Str msg, FileLoc loc, Err? cause := null) : super(msg, loc, cause) {}
}

@Js
internal const class NotReadyErr : Err
{
  new make() : super("") {}
}

