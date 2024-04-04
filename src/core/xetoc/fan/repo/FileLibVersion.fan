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
const class FileLibVersion : LibVersion
{

  new make(Str name, Version version, File file, Str doc, LibDepend[]? depends)
  {
    this.name       = name
    this.version    = version
    this.fileRef    = file
    this.doc        = doc
    this.dependsRef = AtomicRef(depends?.toImmutable)
  }

  override const Str name

  override const Version version

  override const Str doc

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
    d := dependsRef.val
    if (d == null) dependsRef.val = d = loadDepends.toImmutable
    return d
  }

  private const AtomicRef dependsRef

  private LibDepend[] loadDepends()
  {
    if (name == "sys") return LibDepend#.emptyList

    if (file.isDir) return parseDepends(file.plus(`lib.xeto`))

    zip := Zip.open(file)
    try
      return parseDepends(zip.contents.getChecked(`/lib.xeto`))
    finally
      zip.close
  }

  private LibDepend[] parseDepends(File f)
  {
    echo("~~ parseDepends $f")
    return LibDepend[,]
  }
}

