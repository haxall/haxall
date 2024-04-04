//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Apr 2024  Brian Frank  Creation
//

using concurrent
using xeto

**
** LibVersion implementation for FileRepo
**
@Js
const class FileLibVersion : LibVersion
{
  new make(Str name, Version version, File file)
  {
    this.name    = name
    this.version = version
    this.fileRef = file
  }

  override const Str name

  override const Version version

  override const Str doc := ""

  override File? file(Bool checked := true) { fileRef }
  const File fileRef

  override Str toStr() { "$name-$version [$file.osPath]" }

  override Int compare(Obj that)
  {
    a := this
    b := (FileLibVersion)that
    if (a.name != b.name) return a.name <=> b.name
    return a.version <=> b.version
  }

  override LibDepend[] depends()
  {
    if (name == "sys") return LibDepend#.emptyList
echo("TODO: load depends $file")
return LibDepend[,]
  }

  const File? srcDir
}

