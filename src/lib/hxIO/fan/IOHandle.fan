//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Nov 2010  Brian Frank  Creation
//

using web
using ftp
using haystack
using hx

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
  static IOHandle fromObj(Obj? h)
  {
    if (h is IOHandle) return h
    if (h is Str)      return StrHandle(h)
    if (h is Uri)      return fromUri(h, curContext)
    if (h is Dict)     return fromDict(h, "file", curContext)
    if (h is Buf)      return BufHandle(h)
    throw ArgErr("Cannot obtain IO handle from ${h?.typeof}")
  }

  internal static IOHandle fromUri(Uri uri, HxContext cx)
  {
    if (uri.scheme == "http")  return HttpHandle(uri)
    if (uri.scheme == "https") return HttpHandle(uri)
    if (uri.scheme == "ftp")   return FtpHandle(uri)
    if (uri.scheme == "ftps")  return FtpHandle(uri)
    if (uri.scheme == "fan")   return FanHandle(uri)
    return FileHandle(uri ,cx)
  }

  internal static IOHandle fromDict(Dict rec, Str tag, HxContext cx)
  {
    // if {zipEntry, file: <ioHandle>, path: <Uri>}
    if (rec.has("zipEntry"))
      return ZipEntryHandle(cx, fromObj(rec->file).toFile("ioZipEntry"), rec->path)

    id  := rec["id"] as Ref
    bin := rec[tag] as Bin
    if (id ==  null || bin == null) throw ArgErr("Dict has missing/incorrect 'id' and '$tag' tags")
    return BinHandle(rec, tag, cx)
  }

  internal static HxContext curContext() { HxContext.curHx }

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
  ** Process input stream and guarnatee closed.
  ** Return result of function f.
  **
  Obj? withIn(|InStream in->Obj?| f)
  {
    in := this.in
    try
      return f(in)
    finally
      in.close
  }

  **
  ** Process input stream and guarnatee closed.
  ** Return null.
  **
  virtual Obj? withOut(|OutStream out| f)
  {
    out := this.out
    try
      f(out)
    finally
      out.close
    return withOutResult
  }

  **
  ** Open handle as an input stream.
  **
  abstract InStream in()

  **
  ** Open handle as an output stream.
  **
  abstract OutStream out()

  **
  ** Result from withOut
  **
  internal virtual Obj? withOutResult() { null }

  **
  ** Read entire input stream into memory as buffer
  **
  virtual Buf inToBuf() { withIn |in| { in.readAllBuf } }
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

  override InStream in()
  {
    in := handle.in
    in.charset = charset
    return in
  }

  override OutStream out()
  {
    out := handle.out
    out.charset = charset
    return out
  }

  override Obj? withOutResult()
  {
    handle.withOutResult
  }

  IOHandle handle
  const Charset charset
}

**************************************************************************
** StrHandle
**************************************************************************

internal class StrHandle : IOHandle
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

internal class BufHandle : IOHandle
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
  new make(Uri uri, HxContext cx)
  {
    this.projDir = cx.rt.dir
    this.file    = cx.fileResolve(uri)
  }

  private new makeAppend(File projDir, File file)
  {
    this.projDir = projDir; this.file = file; this.append = true
  }

  const File projDir
  const File file
  const Bool append
  override File toFile(Str func) { file }
  override IOHandle toAppend() { makeAppend(projDir, file) }
  override InStream in() { file.in }
  override OutStream out() { file.out(append) }
  override Obj? withOutResult() { Etc.makeDict(["size":Number.makeInt(file.size ?: 0)]) }
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
** BinHandle
**************************************************************************

internal class BinHandle : IOHandle
{
  new make(Dict rec, Str tag, HxContext cx)
  {
    try
    {
      this.proj = cx->proj
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

internal class ZipEntryHandle : IOHandle
{
  new make(HxContext cx, File file, Uri path)
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
  override InStream in() { Zip.gzipInStream(handle.in) }
  override OutStream out() { Zip.gzipOutStream(handle.out) }
}

**************************************************************************
** FanHandle
**************************************************************************

internal class FanHandle : IOHandle
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

internal class HttpHandle : IOHandle
{
  new make(Uri uri) { this.uri = uri }
  const Uri uri
  override InStream in() { WebClient(uri).getIn }
  override OutStream out() { throw UnsupportedErr("Cannot write to HTTP handle")  }
}

**************************************************************************
** FtpHandle
**************************************************************************

internal class FtpHandle : IOHandle
{
  new make(Uri uri) { this.uri = uri }
  const Uri uri
  override Void delete()
  {
    if (uri.isDir)
    {
      // recursively delete the directory
      dir().each |item| { FtpHandle(item.uri).delete }
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
    return client.write(uri)
  }
  override DirItem[] dir() { open(uri).list(uri).map |uri->DirItem| { DirItem(uri, uri.name, uri.mimeType, false, null, null) } }

  FtpClient open(Uri uri)
  {
    key := uri.plus(`/`).toStr
    cx := curContext
    log := cx.rt.lib("io").log
    cred := cx.db.passwords.get(key) ?: "anonymous:"
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

  override OutStream out() { throw UnsupportedErr("Cannot write to ioSkip handle")  }

  override InStream in()
  {
    in := handle.in
    if (opts.has("bom"))   skipBom(in)
    if (opts.has("bytes")) skipBytes(in, toInt("bytes"))
    if (opts.has("chars")) skipChars(in, toInt("chars"))
    if (opts.has("lines")) skipLines(in, toInt("lines"))
    return in
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