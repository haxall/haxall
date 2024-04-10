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

  new make(Str name, Version version, File file, Str? doc, LibDepend[]? depends)
  {
    this.name       = name
    this.version    = version
    this.fileRef    = file
    this.docRef     = doc
    this.dependsRef = depends?.toImmutable
  }

  override const Str name

  override const Version version

  override Str doc()
  {
    if (docRef == null) loadMeta
    return docRef
  }
  private const Str? docRef

  override File? file(Bool checked := true) { fileRef }
  const File fileRef

  override Bool isSrc() { fileRef.isDir }

  override Str toStr() { "$name-$version" }

  override LibDepend[] depends()
  {
    if (dependsRef == null) loadMeta
    return dependsRef
  }

  private const LibDepend[]? dependsRef

  private Void loadMeta()
  {
    if (file.isDir) throw Err("src meta must be passed to make")

    zip := Zip.open(file)
    try
      parseMeta(zip.contents.getChecked(`/meta.props`))
    finally
      zip.close
  }

  private Void parseMeta(File f)
  {
    // parse meta.props
    props := f.readProps

    // doc
    doc := props["doc"] ?: ""
    #docRef->setConst(this, doc)

    // depends
    depends := LibDepend#.emptyList
    dependsStr := props["depends"]?.trimToNull
    if (dependsStr != null) depends = dependsStr.split(';').map |s->LibDepend| { LibDepend(s) }
    #dependsRef->setConst(this, depends.toImmutable)
  }
}

