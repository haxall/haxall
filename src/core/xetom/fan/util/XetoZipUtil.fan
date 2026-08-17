//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   3 Aug 2026  Brian Frank  Creation
//

using crypto
using xeto
using haystack

**
** XetoZipUtil is the choke point for building xetolib zip files; it is
** used by the compiler build pipeline, remote repo clients which
** assemble a zip from fetched source, and repo servers which zip a
** local source lib on the fly.
**
const class XetoZipUtil
{
  ** Write a xetolib zip to the given output stream and close it.
  ** Entries are written in the required order: xeto-meta.props,
  ** xeto-build.props if non-empty, then the lib source files.  Files are
  ** written raw so the compiler resolves BuildVar tokens at load time.
  static Void writeLibZip(OutStream out, Str name, Version version, LibDepend[] depends, Dict meta, Str:Str buildProps, MLibFiles files)
  {
    zip := Zip.write(out)
    try
    {
      // xeto-meta.props - required for FileLibVersion.loadZipFile
      zip.writeNext(XetoUtil.xetoMetaPropsUri).writeProps(buildLibMetaProps(name, version, depends, meta)).close

      // xeto-build.props - must be before xeto files (compiler reads it first)
      if (!buildProps.isEmpty) zip.writeNext(XetoUtil.xetoBuildPropsUri).writeProps(buildProps).close

      // source files; preserve modified times when the file has one.
      // srcLibZip and GithubRepo package without compiling, so the names
      // are checked here rather than only by the compiler
      files.list.each |file|
      {
        entryOut := zip.writeNext(file.uri, file.modified ?: DateTime.now)
        file.read |in| { in.pipe(entryOut) }
        entryOut.close
      }
    }
    finally zip.close
  }

  ** Build a xetolib zip into an in-memory buf; see `writeLibZip`
  static Buf buildLibZip(Str name, Version version, LibDepend[] depends, Dict meta, Str:Str buildProps, MLibFiles files)
  {
    buf := Buf()
    writeLibZip(buf.out, name, version, depends, meta, buildProps, files)
    return buf.toImmutable
  }

  ** Build a xetolib zip for a local source lib.  The src directory
  ** files are zipped raw along with the adjacent "xeto-build.props" if
  ** present so the compiler resolves BuildVar tokens at load time.
  static Buf srcLibZip(LibVersion v)
  {
    dir := v.file

    // only user vars are packaged; reserved names configure a source
    // tree we are not shipping
    vars := BuildVars.read(dir.parent + XetoUtil.xetoBuildPropsName.toUri)

    meta := Str:Obj[:]
    meta.addNotNull("doc", v.doc.isEmpty ? null : v.doc)
    if (v.isHxSysOnly) meta["hxSysOnly"] = Marker.val
// TODO
//files := DirLibFilesScanner(dir, LibFilePattern[,],  LibFilePattern[,]).scan |msg| { echo(msg) }
//    return buildLibZip(v.name, v.version, v.depends, Etc.dictFromMap(meta), vars.vars, files)
throw Err("TODO")
  }


  ** Choke point to generate the xetolib meta props contents
  static Str:Str buildLibMetaProps(Str name, Version version, LibDepend[] depends, Dict meta)
  {
    props := Str:Str[:]
    props.ordered = true
    props["name"]    = name
    props["version"] = version.toStr
    props["depends"] = depends.join(";")
    props["doc"]     = meta["doc"] as Str ?: ""
    props.addNotNull("publish", (meta["publish"] as List)?.join(";")?.trimToNull)
    props.addNotNull("hxSysOnly", meta.has("hxSysOnly") ? "true" : null)
    return props
  }

//////////////////////////////////////////////////////////////////////////
// Digest
//////////////////////////////////////////////////////////////////////////

  ** Choke point to format digest of xetolib zip contents as "sha256:"
  ** followed by the base64uri encoding of the SHA-256 hash
  static Str digest(Buf contents)
  {
    digestFrom(Crypto.cur.digest("SHA-256").update(contents))
  }

  ** Digest a stream incrementally without buffering its contents.  The
  ** stream is read to exhaustion, and if close is true it is guaranteed
  ** closed upon return - matching the semantics of `sys::InStream.pipe`.
  ** Use this instead of `digest` when the content may be large, such as
  ** an uploaded lib zip or one of its entries.
  static Str digestStream(InStream in, Bool close := true)
  {
    d := Crypto.cur.digest("SHA-256")
    chunkSize := 64*1024
    buf := Buf(chunkSize)
    try
      while (in.readBuf(buf.clear, chunkSize) != null) d.update(buf.flip)
    finally
      if (close) in.close
    return digestFrom(d)
  }

  ** Choke point to format the hash of a completed digest computation;
  ** see `digest` and `digestStream`
  static Str digestFrom(Digest d)
  {
    "sha256:" + d.digest.toBase64Uri
  }
}

