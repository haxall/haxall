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
const class FileLibVersion : LibVersion
{

  new make(Str name, Version version, File file, Str? doc, Int flags, LibDepend[]? depends)
  {
    this.name       = name
    this.version    = version
    this.toStr      = "$name-$version"
    this.fileRef    = file
    this.docRef     = doc
    this.flagsRef   = flags
    this.dependsRef = depends?.toImmutable
  }

  new makeFile(File file)
  {
    n := file.basename
    dash := n.index("-") ?: throw Err(n)
    this.name    = n[0..<dash]
    this.version = Version(n[dash+1..-1])
    this.toStr   = "$name-$version"
    this.fileRef = file
  }

  new makeProj(File dir, Version version)
  {
    this.name       = XetoUtil.projLibName
    this.version    = version
    this.toStr      = "$name-$version"
    this.fileRef    = dir
    this.docRef     = "Project library"
    this.dependsRef = LibDepend#.emptyList
  }

  new makeNotFound(Str name)
  {
    this.name       = name
    this.version    = Version("0.0.0")
    this.toStr      = "$name-$version"
    this.fileRef    = notFoundFile
    this.docRef     = "Not found"
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

  override LibDepend[] depends() { loadMeta.dependsRef }
  private const LibDepend[]? dependsRef

  override Str doc() { loadMeta.docRef }
  private const Str? docRef

  override Int flags() { loadMeta.flagsRef }
  private const Int flagsRef

  private This loadMeta()
  {
    if (dependsRef != null) return this

    if (file.isDir) throw Err("src meta must be passed to make")

    zip := Zip.open(file)
    try
      parseMeta(zip.contents.getChecked(`/meta.props`))
    finally
      zip.close

    return this
  }

  private Void parseMeta(File f)
  {
    // parse meta.props
    props := f.readProps

    // doc
    doc := props["doc"] ?: ""
    #docRef->setConst(this, doc)

    // flags
    flags := 0
    if (props["hxSysOnly"] != null) flags = flags.or(flagHxSysOnly)
    #flagsRef->setConst(this, flags)

    // depends
    depends := LibDepend#.emptyList
    dependsStr := props["depends"]?.trimToNull
    if (dependsStr != null) depends = dependsStr.split(';').map |s->LibDepend| { parseDepend(s) }
    #dependsRef->setConst(this, depends.toImmutable)
  }

  private static LibDepend parseDepend(Str s)
  {
    sp := s.index(" ") ?: throw ParseErr("Invalid depend: $s")
    n  := s[0..<sp].trim
    v  := LibDependVersions(s[sp+1..-1])
    return MLibDepend(n, v)
  }

  private static const File notFoundFile := Buf().toFile(`not-found`)

  override Bool isNotFound() { file === notFoundFile }
}

