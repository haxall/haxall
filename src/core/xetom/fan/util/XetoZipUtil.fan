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
  ** Entries are written in the required order: meta.props, build.props
  ** if non-empty, then the given files keyed by zip path.  File values
  ** may be Str content or File instances; they are written raw so the
  ** compiler resolves BuildVar tokens at load time.
  static Void writeLibZip(OutStream out, Str name, Version version, LibDepend[] depends, Dict meta, Str:Str buildProps, Uri:Obj files)
  {
    zip := Zip.write(out)
    try
    {
      // meta.props - required for FileLibVersion.loadZipFile
      zip.writeNext(`/meta.props`).writeProps(buildLibMetaProps(name, version, depends, meta)).close

      // build.props - must be before xeto files (compiler reads it first)
      if (!buildProps.isEmpty) zip.writeNext(`/build.props`).writeProps(buildProps).close

      // source files; preserve modified times for file content
      files.each |content, path|
      {
        file := content as File
        entryOut := file == null ? zip.writeNext(path) : zip.writeNext(path, file.modified)
        if (file != null) file.in.pipe(entryOut)
        else entryOut.print(content)
        entryOut.close
      }
    }
    finally zip.close
  }

  ** Build a xetolib zip into an in-memory buf; see `writeLibZip`
  static Buf buildLibZip(Str name, Version version, LibDepend[] depends, Dict meta, Str:Str buildProps, Uri:Obj files)
  {
    buf := Buf()
    writeLibZip(buf.out, name, version, depends, meta, buildProps, files)
    return buf.toImmutable
  }

  ** Build a xetolib zip for a local source lib.  The src directory
  ** files are zipped raw along with the adjacent "build.props" if
  ** present so the compiler resolves BuildVar tokens at load time.
  static Buf srcLibZip(LibVersion v)
  {
    dir := v.file

    // only user vars are packaged; reserved names configure a source
    // tree we are not shipping
    buildProps := BuildVars.read(dir.parent + `build.props`).vars

    meta := Str:Obj[:]
    meta.addNotNull("doc", v.doc.isEmpty ? null : v.doc)
    if (v.isHxSysOnly) meta["hxSysOnly"] = Marker.val
    return buildLibZip(v.name, v.version, v.depends, Etc.dictFromMap(meta), buildProps, dirFiles(dir))
  }

  ** Map a source directory to zip path entries; see `LibSrcFiles`
  static Uri:File dirFiles(File dir) { LibSrcFiles.makeDir(dir).map }

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

  ** Chunk size used to stream content through a digest
  internal static const Int chunkSize := 64 * 1024

  ** Choke point to generate a xetolib meta.props contents
  static Str:Str buildLibMetaProps(Str name, Version version, LibDepend[] depends, Dict meta)
  {
    props := Str:Str[:]
    props.ordered = true
    props["name"]    = name
    props["version"] = version.toStr
    props["depends"] = depends.join(";")
    props["doc"]     = meta["doc"] as Str ?: ""
    props.addNotNull("hxSysOnly", meta.has("hxSysOnly") ? "true" : null)
    return props
  }
}

