//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Nov 2010  Brian Frank  Creation
//

using web
using ftp
using xeto
using haystack
using hx
using folio

**
** IOHandle is the standard handle used to open an input/output stream.
**
abstract class IOHandle
{

//////////////////////////////////////////////////////////////////////////
// Factories
//////////////////////////////////////////////////////////////////////////

  **
  ** Constructor from arbitrary object:
  **   - sys::Str
  **   - sys::Uri like "io/..."
  **   - sys::Dict
  **   - sys::Buf
  **
  static IOHandle fromObj(HxRuntime rt, Obj? h)
  {
    if (h is IOHandle) return h
    if (h is Str)      return StrHandle(h)
    if (h is Uri)      return fromUri(rt, h)
    if (h is Dict)     return fromDict(rt, h)
    if (h is Buf)      return BufHandle(h)
    throw ArgErr("Cannot obtain IO handle from ${h?.typeof}")
  }

  internal static IOHandle fromUri(HxRuntime rt, Uri uri)
  {
    if (uri.scheme == "http")  return HttpHandle(uri)
    if (uri.scheme == "https") return HttpHandle(uri)
    if (uri.scheme == "ftp")   return FtpHandle(rt, uri)
    if (uri.scheme == "ftps")  return FtpHandle(rt, uri)
    if (uri.scheme == "fan")   return FanHandle(uri)
    return FileHandle(rt.file.resolve(uri))
  }

  ** Get an IOHandle from a Dict rec. If a tag is specified, then the the
  ** rec is treated as a Bin (deprecated feature). For backwards compatibility
  ** if a null tag is specified, we check if the rec has a 'file' Bin tag; if it
  ** does we treat it as a Bin. In all other cases the rec is a folio file.
  internal static IOHandle fromDict(HxRuntime rt, Dict rec, Str? tag := null)
  {
    // if {zipEntry, file: <ioHandle>, path: <Uri>}
    if (rec.has("zipEntry"))
      return ZipEntryHandle(fromObj(rt, rec->file).toFile("ioZipEntry"), rec->path)

    // must have valid id
    id := rec["id"] as Ref
    if (id == null) throw ArgErr("Dict has missing/invalid 'id' tag")

    // check for explicit bin tag
    if (tag != null) return tryBin(rt, rec, tag)

    // check for implicit 'file' Bin, otherwise return a folio file handle
    return tryBin(rt, rec, "file", false) ?: FolioFileHandle(rt, rec)
  }

  private static BinHandle? tryBin(HxRuntime rt, Dict rec, Str tag, Bool checked := true)
  {
    bin := rec[tag] as Bin
    if (bin != null) return BinHandle(rt, rec, tag)
    if (checked) throw ArgErr("Dict '${tag}' tag is not a Bin")
    return null
  }

//////////////////////////////////////////////////////////////////////////
// I/O
//////////////////////////////////////////////////////////////////////////

  **
  ** Get this handle as a file or throw ArgErr if not a file
  **
  virtual File toFile(Str func)
  {
    throw UnsupportedErr("Cannot run $func on $typeof.name")
  }

  **
  ** Return directory of this handle for ioDir
  **
  virtual DirItem[] dir()
  {
    throw UnsupportedErr("Cannot run ioDir() on $typeof.name")
  }

  **
  ** Convert this handle to an append mode handle.
  **
  virtual IOHandle toAppend()
  {
    throw UnsupportedErr("Append mode not supported on $typeof.name")
  }

  **
  ** Create an empty file or directory for this handle.
  **
  virtual Void create() { toFile("create").create }

  **
  ** Delete the file or directory specified for this handle
  **
  virtual Void delete() { toFile("delete").delete }

  ** Get file information about the current handle or throw an Err if not a file
  virtual DirItem info()
  {
    f := toFile("info")
    return DirItem(f.uri, f)
  }

  **
  ** Process the input stream and guarantee closed.
  ** Return result of function f.
  **
  abstract Obj? withIn(|InStream in->Obj?| f)

  **
  ** Process the output stream and guarantee closed.
  ** Returns 'null' or a sub-class specific result after the write is completed.
  **
  abstract Obj? withOut(|OutStream out| f)

  **
  ** Read entire input stream into memory as buffer
  **
  virtual Buf inToBuf() { withIn |in| { in.readAllBuf } }
}

**************************************************************************
** DirectIO
**************************************************************************

**
** DirectIO allows for direct access to the input and output streams.
**
** The public API is still `withIn` and `withOut` but this class provides
** a convenient pattern for IOHandles that have this type of access to their
** I/O streams.
**
internal abstract class DirectIO : IOHandle
{
  final override Obj? withIn(|InStream in->Obj?| f)
  {
    in := this.in
    try
      return f(in)
    finally
      in.close
  }

  final override Obj? withOut(|OutStream out| f)
  {
    out := this.out
    try
      f(out)
    finally
      out.close
    return withOutResult
  }

  ** Get direct access to the input stream for this handle
  abstract InStream in()

  ** Get direct access to the output stream for this handle.
  abstract OutStream out()

  ** Result from `withOut`. Defaults to null
  virtual Obj? withOutResult() { null }
}

**************************************************************************
** DirItem
**************************************************************************

const class DirItem
{
  new makeFile(Uri uri, File file)
  {
    this.uri   = uri
    this.name  = file.name
    this.mime  = file.mimeType
    this.isDir = file.isDir
    this.size  = file.size
    this.mod   = file.modified
  }


  new make(Uri uri, Str name, MimeType? mime, Bool isDir, Int? size, DateTime? mod)
  {
    this.uri   = uri
    this.name  = name
    this.mime  = mime
    this.isDir = isDir
    this.size  = size
    this.mod   = mod
  }

  const Uri uri
  const Str name
  const MimeType? mime
  const Bool isDir
  const Int? size
  const DateTime? mod
}

**************************************************************************
** CharsetHandle
**************************************************************************

internal class CharsetHandle : IOHandle
{
  new make(IOHandle h, Charset charset) { this.handle = h; this.charset = charset }

  override Obj? withIn(|InStream in->Obj?| f)
  {
    handle.withIn |in->Obj?|
    {
      in.charset = charset
      return f(in)
    }
  }

  override Obj? withOut(|OutStream out| f)
  {
    handle.withOut |out|
    {
      out.charset = charset
      f(out)
    }
  }

  IOHandle handle
  const Charset charset
}

**************************************************************************
** StrHandle
**************************************************************************

internal class StrHandle : DirectIO
{
  new make(Str s) { this.str = s }
  const Str str
  StrBuf? buf
  override InStream in() { str.in }
  override OutStream out() { this.buf = StrBuf().add(str); return buf.out }
  override Obj? withOutResult() { buf.toStr }
  override Buf inToBuf() { str.toBuf }
}

**************************************************************************
** BufHandle
**************************************************************************

internal class BufHandle : DirectIO
{
  new make(Buf buf) { this.buf = buf }
  Buf buf { private set }
  override File toFile(Str func) { buf.toFile(`$func`) }
  override InStream in() { buf.in }
  override OutStream out() { buf.out }
  override Obj? withOutResult() { Etc.makeDict(["size":Number.makeInt(buf.size)]) }
}

**************************************************************************
** FileHandle
**************************************************************************

internal class FileHandle : IOHandle
{
  new make(File file)
  {
    this.file = file
  }

  private new makeAppend(File file)
  {
    this.file = file; this.append = true
  }

  const File file
  const Bool append
  override File toFile(Str func) { file }
  override IOHandle toAppend() { makeAppend(file) }
  override Obj? withIn(|InStream->Obj?| f)
  {
    file.withIn(f)
  }
  override Obj? withOut(|OutStream| f)
  {
    if (append)
    {
      out := file.out(true)
      try
        f(out)
      finally
        out.close
    }
    else
    {
      file.withOut(f)
    }
    return Etc.makeDict(["size":Number.makeInt(file.size ?: 0)])
  }
  override DirItem[] dir()
  {
    kids := file.list
    acc := DirItem[,]
    acc.capacity = kids.size
    kids.each |kid|
    {
      if (kid.isHidden) return
      acc.add(DirItem(kid.uri, kid))
    }
    return acc
  }
  override DirItem info() { DirItem(file.uri, file) }
}

**************************************************************************
** FolioFileHandle
**************************************************************************

internal class FolioFileHandle : IOHandle
{
  new make(HxRuntime rt, Dict rec)
  {
    this.folio = rt.db
    this.rec   = rec
  }

  const Folio folio
  const Dict rec

  override Obj? withIn(|InStream->Obj?| f)
  {
    folio.file.get(rec.id).withIn(f)
  }

  override Obj? withOut(|OutStream| f)
  {
    folio.file.get(rec.id).withOut(f)
    return null
  }
}

**************************************************************************
** BinHandle
**************************************************************************

internal class BinHandle : DirectIO
{
  new make(HxRuntime rt, Dict rec, Str tag)
  {
    try
    {
      this.proj = rt->proj
      this.rec  = rec
      this.tag  = tag
    }
    catch (UnknownSlotErr e) throw Err("Cannot use bin files outside of SkySpark")
  }
  const Obj proj
  const Dict rec
  const Str tag
  override InStream in() { proj->readBin(rec, tag) }
  override OutStream out() { proj->writeBin(rec, tag, null) }
}

**************************************************************************
** ZipEntryHandle
**************************************************************************

internal class ZipEntryHandle : DirectIO
{
  new make(File file, Uri path)
  {
    this.file = file
    this.path = path
  }
  const File file
  const Uri path
  override InStream in()
  {
    zip := IOUtil.openZip(file)
    entry := zip.contents[path] ?: throw Err("Zip entry not found: $file | $path")
    return ZipEntryInStream(zip, entry.in)
  }
  override OutStream out() { throw UnsupportedErr("Cannot write to ZipEntry")  }
}

internal class ZipEntryInStream : InStream
{
  new make(Zip zip, InStream in) : super(in) { this.zip = zip }
  private Zip zip
  override Bool close() { super.close; return zip.close }
}

**************************************************************************
** GZipEntryHandle
**************************************************************************

internal class GZipEntryHandle : IOHandle
{
  new make(IOHandle handle) { this.handle = handle }
  IOHandle handle
  override Obj? withIn(|InStream->Obj?| f)
  {
    handle.withIn |in->Obj?|
    {
      zipIn := Zip.gzipInStream(in)
      try
        return f(zipIn)
      finally
        zipIn.close
    }
  }
  override Obj? withOut(|OutStream| f)
  {
    handle.withOut |out|
    {
      zipOut := Zip.gzipOutStream(out)
      try
        f(zipOut)
      finally
        zipOut.close
    }
  }
}

**************************************************************************
** FanHandle
**************************************************************************

internal class FanHandle : DirectIO
{
  new make(Uri uri) { this.uri = uri }
  const Uri uri
  override InStream in() { toFanFile.in }
  override OutStream out() { throw UnsupportedErr("Cannot write to fan:// handle")  }
  override DirItem[] dir()
  {
    if (uri.path.size > 0) throw UnsupportedErr("Use empty path such as fan://podName/")
    files := Pod.find(uri.host).files.findAll |f|
    {
      if  (f.path.first == "lib") return false  // don't allow network access to Axon funcs in lib/
      if (f.ext == "apidoc") return false
      return true
    }
    return files.map |f->DirItem| { DirItem(f.uri, f) }
  }
  private File toFanFile()
  {
    f := (File)uri.get
    // don't allow network access to Axon funcs in lib/
    if (f.path.first == "lib") throw UnresolvedErr(uri.toStr)
    return f
  }
}

**************************************************************************
** HttpHandle
**************************************************************************

internal class HttpHandle : DirectIO
{
  new make(Uri uri) { this.uri = uri }
  const Uri uri
  override InStream in() { toClient.getIn }
  override OutStream out() { throw UnsupportedErr("Cannot write to HTTP handle")  }
  override File toFile(Str func) { toClient.getBuf.toFile(uri.name.toUri) }
  WebClient toClient() { WebClient(uri) }
}

**************************************************************************
** FtpHandle
**************************************************************************

internal class FtpHandle : DirectIO
{
  new make(HxRuntime rt, Uri uri) { this.rt = rt; this.uri = uri }
  const HxRuntime rt
  const Uri uri
  override Void create()
  {
    if (uri.isDir)
      open(uri).mkdir(uri)
    else
      this.out
  }
  override Void delete()
  {
    if (uri.isDir)
    {
      // recursively delete the directory
      dir().each |item| { FtpHandle(rt, item.uri).delete }
      open(uri).rmdir(uri)
    }
    else open(uri).delete(uri)
  }
  override InStream in() { open(uri).read(uri) }
  override OutStream out()
  {
    client := open(uri)
    // make sure parent directories exist
    client.mkdir(uri.parent)

    // re-open client for writing uri
    client = open(uri)
    return client.write(uri)
  }
  override DirItem[] dir() { open(uri).list(uri).map |uri->DirItem| { DirItem(uri, uri.name, uri.mimeType, false, null, null) } }

  FtpClient open(Uri uri)
  {
    key := uri.plus(`/`).toStr
    log := rt.libsOld.get("io").log
    cred := rt.db.passwords.get(key) ?: "anonymous:"
    colon := cred.index(":")
    if (colon == null) throw Err("ftp credentials not 'user:pass' - $cred.toCode")
    user := cred[0..<colon]
    pass := cred[colon+1..-1]
    if (log.isDebug) log.debug("FtpClient.open uri=$key.toCode user=$user.toCode")
    c := FtpClient(user, pass)
    c.log = log
    return c
  }
}

**************************************************************************
** SkipHandle
**************************************************************************

internal class SkipHandle : IOHandle
{
  new make(IOHandle h, Dict opts)
  {
    this.handle = h
    this.opts = opts
  }

  override Obj? withOut(|OutStream| f) { throw UnsupportedErr("Cannot write to ioSkip handle") }

  override Obj? withIn(|InStream->Obj?| f)
  {
    handle.withIn |in->Obj?|
    {
      if (opts.has("bom"))   skipBom(in)
      if (opts.has("bytes")) skipBytes(in, toInt("bytes"))
      if (opts.has("chars")) skipChars(in, toInt("chars"))
      if (opts.has("lines")) skipLines(in, toInt("lines"))
      return f(in)
    }
  }

  private Void skipBytes(InStream in, Int num)
  {
    num.times { in.read }
  }

  private Void skipChars(InStream in, Int num)
  {
    num.times { in.readChar }
  }

  private Void skipLines(InStream in, Int num)
  {
    num.times { in.readLine }
  }

  private Void skipBom(InStream in)
  {
    b1 := in.read

    // UTF-16 Big Endian: 0xFE_FF BOM
    if (b1 == 0xFE)
    {
      b2 := in.read
      if (b2 == 0xFF) { in.charset = Charset.utf16BE; return }
      in.unread(b2).unread(b1)
    }

    // UTF-16 Little Endian: 0xFF_FE BOM
    if (b1 == 0xFF)
    {
      b2 := in.read
      if (b2 == 0xFE) { in.charset = Charset.utf16LE; return }
      in.unread(b2).unread(b1)
    }

    // UTF-8 BOM: 0xEF_BB_BF
    if (b1 == 0xEF)
    {
      b2 := in.read
      if (b2 == 0xBB)
      {
        b3 := in.read
        if (b3 != 0xBF) throw IOErr("Invalid UTF-8 BOM 0xef_bb_${b3.toHex}")
        in.charset = Charset.utf8
        return
      }
      in.unread(b2).unread(b1)
      return
    }

    // push back first byte
    in.unread(b1)
  }

  private Int toInt(Str tag)
  {
    num := opts.trap(tag) as Number ?: throw ArgErr("Opt $tag must be Number")
    return num.toInt
  }

  IOHandle handle
  const Dict opts
}

