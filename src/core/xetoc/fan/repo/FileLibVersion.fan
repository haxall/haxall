//
// Copyright (c) 2024, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Apr 2024  Brian Frank  Creation
//

using concurrent
using xeto
using xetom

**
** LibVersion implementation for FileRepo
**
@Js
const class FileLibVersion : LibVersion
{

  new make(Str name, Version version, File file, Str doc, Int flags, LibDepend[] depends)
  {
    this.name       = name
    this.version    = version
    this.toStr      = "$name-$version"
    this.fileRef    = file
    this.doc        = doc
    this.flags      = flags
    this.dependsRef = depends.toImmutable
  }

  new makeCompanion(Version version)
  {
    this.name       = XetoUtil.companionLibName
    this.version    = version
    this.toStr      = "$name-$version"
    this.fileRef    = notUsedFile
    this.doc        = "Project library"
    this.dependsRef = LibDepend#.emptyList
  }

  new makeNotFound(Str name)
  {
    this.name       = name
    this.version    = Version("0.0.0")
    this.toStr      = "$name-$version"
    this.fileRef    = notFoundFile
    this.doc        = "Not found"
    this.dependsRef = LibDepend#.emptyList
  }

  override const Str name

  override const Version version

  override const Str toStr

  override File? file(Bool checked := true) { fileRef }
  const File fileRef

  override Bool isSrc() { fileRef.isDir }

  override Void eachSrcFile(|File| cb)
  {
    if (isSrc)
    {
      file.walk |f| { if (f.ext == "xeto") cb(f) }
    }
    else
    {
      zip := Zip.open(file)
      try
        zip.contents.each |f| { if (f.ext == "xeto") cb(f) }
      finally
        zip.close
    }
  }

  override LibDepend[]? depends(Bool checked := true) { dependsRef }
  private const LibDepend[] dependsRef

  override LibOrigin? origin() { null } // TODO

  override const Str doc

  override const Int flags

  private static const File notFoundFile := Buf().toFile(`not-found`)
  private static const File notUsedFile := Buf().toFile(`not-used`)

  override Bool isNotFound() { file === notFoundFile }

  override Bool isCompanion() { name === XetoUtil.companionLibName }
}

