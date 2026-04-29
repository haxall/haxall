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

//////////////////////////////////////////////////////////////////////////
// Load
//////////////////////////////////////////////////////////////////////////

  ** Load from xetolib zip
  static FileLibVersion loadZipFile(File file)
  {
    // sanity check name
    name := file.basename
    err := XetoUtil.libNameErr(name)
    if (err != null) throw Err("Invalid lib name $name.toCode [$file.osPath]")

    // try to parse meta.props
    [Str:Str]? props
    zip := Zip.open(file)
    try
    {
      propsFile := zip.contents.get(`/meta.props`) ?: throw Err("Missing 'meta.props' in zip")
      props = propsFile.readProps
    }
    finally zip.close

    // version
    version := Version.fromStr(props.getChecked("version"))

    // doc
    doc := props["doc"] ?: ""

    // flags
    flags := 0
    if (props["hxSysOnly"] != null) flags = flags.or(FileLibVersion.flagHxSysOnly)

    // depends
    depends := LibDepend#.emptyList
    dependsStr := props["depends"]?.trimToNull
    if (dependsStr != null) depends = dependsStr.split(';').map |s->LibDepend| { parseDepend(s) }

    // create
    return FileLibVersion(name, version, file, doc, flags, depends)
  }

  private static LibDepend parseDepend(Str s)
  {
    sp := s.index(" ") ?: throw ParseErr("Invalid depend: $s")
    n  := s[0..<sp].trim
    v  := LibDependVersions(s[sp+1..-1])
    return MLibDepend(n, v)
  }
}

