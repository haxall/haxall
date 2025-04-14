//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  12 Dec 2024  Matthew Giannini Creation
//

using util
using haystack
using haystack::Ref
using haystack::Dict
using xeto

**
** FolioFile provides an API for storing file data associated with a rec
** in Folio. Folio stores a rec that describes metadata about the file.
** Implementations will typically store the actual file contents
** to the local filesystem or cloud.
**
** Files stored in a FolioFile implementation have certain constraints. You
** can only read and write them using `File.withIn` and `File.withOut` respectively.
** You will get an `IOErr` if you attempt to use `File.in` or `File.out`. After a write
** to a file, the corresponding rec in Folio will asynchronously be updated to add
** the 'fileSize' tag (size in bytes).
**
** `File.exists` will only return 'true' if the backing file exists; that is, it
** has been written to. `File.delete` will delete the backing file, but will not
** delete the corresponding rec in Folio.
**
** When a file rec is removed from Folio, it's backing file is also removed from the
** backing store.
**
@NoDoc
const mixin FolioFile
{
  ** Get the backing [file]`File` for the rec with the given id. If there is
  ** no rec with the given id, through an error if checked, or return null.
  **
  ** See `FolioFile` for more details about working with the backing file.
  abstract File? get(Ref id, Bool checked := true)
}

**************************************************************************
** MFolioFile
**************************************************************************

@NoDoc
const abstract class MFolioFile : FolioFile
{
  new make(Folio folio)
  {
    this.folio = folio
  }

  ** Folio instance
  const Folio folio

  ** Utility to normalize the ref for consistency
  protected static Ref norm(Ref id)
  {
    id = id.toProjRel
    id = Ref(Etc.toFileName(id.id))
    return id
  }

  override File? get(Ref id, Bool checked := true)
  {
    id = norm(id)

    // lookup rec
    rec  := folio.readById(id, false)
    if (rec == null) return onErr(id, checked, "Folio rec not found")

    // check spec
    spec := rec.get("spec") as Ref
    if (spec == null) return onErr(id, checked, "Folio rec is missing spec")
    if (!xeto.spec(spec.id).isa(xeto.spec("sys::File"))) return onErr(id, checked, "Folior rec is not Xeto sys::File")

    return toFile(id)
  }

  ** Get the xeto namespace
  LibNamespace xeto() { LibNamespace.system }

  ** Sub-class hook to make a file instance for the rec with this id.
  protected abstract File toFile(Ref id)

  ** Handle checked errors
  protected File? onErr(Ref id, Bool checked, Str msg)
  {
    if (checked) throw Err("${msg}: ${id}")
    return null
  }
}

**************************************************************************
** LocalFolioFile
**************************************************************************

**
** Break out the implementation for local file storage so that
** it can be easily re-used.
**
** Files are hashed into a directory buckets so they aren't all in one
** big directory.
**
@NoDoc
const class LocalFolioFile : MFolioFile
{
  new make(Folio folio) : super(folio)
  {
    this.dir = folio.dir.plus(`../files/`)
  }

  ** Root directory for storing files
  const File dir

  protected override File toFile(Ref id)
  {
    LocalRecFile(this, id)
  }
}

**************************************************************************
** RecFile
**************************************************************************

** Utility base class for a rec file.
@NoDoc
const abstract class RecFile : SyntheticFile
{
  ** Make a RecFile for the rec with this id. It is assumed that
  ** the id is already fully normalized.
  new make(Folio folio, Ref id) : super(`${id}`)
  {
    this.folio = folio
    this.id    = id
  }

  protected const Folio folio
  const Ref id
  Dict? rec(Bool checked := true) { folio.readById(id, checked) }

  ** Sub-types must provide an implementation that adheres to FolioFile semantics
  override abstract Bool exists()

  ** The default implementation gets the 'fileSize' from the folio rec if it is set
  override Int? size()
  {
    (rec(false)?.get("fileSize") as Number)?.toInt
  }

  ** The default implementation gets the 'mod' from the folio rec
  override DateTime? modified
  {
    get { rec(false)?.get("mod") as DateTime }
    set { }
  }

  final override File plus(Uri uri, Bool checkSlash := true)
  {
    // always return a non-existent file if this is used
    SyntheticFile(this.uri.plus(uri))
  }

  override File create()
  {
    if (!exists) withOut(null) |out| { }
    return this
  }

  final override Void delete()
  {
    onDelete
    commitFileSizeAsync(0)
  }

  ** sub-class hook to handle backing file deletion.
  protected abstract Void onDelete()

  final override Obj? withIn([Str:Obj]? opts, |InStream->Obj?| f)
  {
    // we need to override this so that we can route to an internal method
    // of getting an input stream
    bufSize := 4096
    if (opts != null)
    {
      bufSize = opts.get("bufSize", bufSize)
    }
    in := this.makeInStream(bufSize, opts)
    try
      return f(in)
    finally
      in.close
  }

  final override Void withOut([Str:Obj]? opts, |OutStream| f)
  {
    // we need to override this so that we can route to an internal method
    // of getting an output stream
    append  := false
    bufSize := 4096
    if (opts != null)
    {
      append  = opts.get("append", append)
      bufSize = opts.get("bufSize", bufSize)
    }

    // read the rec to ensure it exists
    out := this.makeOutStream(append, bufSize, opts)
    try
      f(out)
    finally
      out.close

    // update the file size
    size := append ? (this.size ?: 0) : 0
    size += out.bytesWritten
    commitFileSizeAsync(size)
  }

  protected FolioFuture? commitFileSizeAsync(Int bytes)
  {
    rec  := this.rec(false)
    if (rec == null) return null

    diff := Diff(rec, ["fileSize": Number(bytes, Number.byte)], Diff.bypassRestricted)
    return folio.commitAsync(diff)
  }

  ** sub-class hook to get the internal InStream to use for reading since File.in
  ** is not allowed for rec files
  protected abstract InStream makeInStream(Int bufferSize, [Str:Obj]? opts)

  ** sub-class hook to get the internal OutStream to sue for writing since File.out
  ** is not allowed for rec files
  protected abstract ChunkedOutStream makeOutStream(Bool append, Int bufferSize, [Str:Obj]? opts)
}

**************************************************************************
** LocalRecFile
**************************************************************************

internal const class LocalRecFile : RecFile
{
  new make(LocalFolioFile folioFile, Ref id) : super(folioFile.folio, id)
  {
    this.localFile = folioFile.dir.plus(`b${id.hash.abs %1024}/${id}`)
  }

  private const File localFile

  override Bool exists()
  {
    localFile.exists
  }

  override DateTime? modified
  {
    get { localFile.modified }
    set { }
  }

  override Void onDelete()
  {
    localFile.delete
  }

  override InStream makeInStream(Int bufferSize, [Str:Obj]? opts)
  {
    localFile.in(bufferSize)
  }

  override ChunkedOutStream makeOutStream(Bool append, Int bufferSize, [Str:Obj]? opts)
  {
    ChunkedOutStream(localFile.out(append, bufferSize))
  }
}

**************************************************************************
** ChunkedOutStream
**************************************************************************

** ChunkedOutStream buffers up writes in-memory to a certain chunk size before
** flushing them to output. This allows us to track important stats about the
** output - notably the number of bytes and chunks written.
**
** If constructed with a non-null OutputStream, all chunks will be written to that
** output stream. However, we manage that instead of delegating that responsibility to
** the OutStream base class. We need to do this because OutStream will not route
** all write operations through write or writeBuf if a wrapped OutStream is supplied.
@NoDoc
class ChunkedOutStream : OutStream
{
  new make(OutStream? out, [Str:Obj?] opts := [:]) : super(null)
  {
    this.out       = out
    this.chunkSize = opts["chunkSize"] ?: (5 * 1024 * 1024)
    this.chunk     = Buf(chunkSize)
  }

  ** We internally handle writes to the wrapped out stream
  protected OutStream? out { private set }

  ** Number of bytes written by this output stream
  Int bytesWritten := 0 { private set }

  Int chunksWritten := 0 { private set }

  ** How large of a chunk to hold in memory before flushing to the output stream
  private const Int chunkSize

  ** The chunk
  private Buf chunk

  ** How much room is left in the current chunk
  private Int chunkRoom() { chunkSize - chunk.size }

  final override This write(Int byte)
  {
    chunk.write(byte)
    return flushIfNeeded
  }

  final override This writeBuf(Buf buf, Int n := buf.remaining)
  {
    while (n > 0)
    {
      num := chunkRoom.min(n)
      buf.readBufFully(chunk, num)
      n -= num
      flushIfNeeded
    }
    return this
  }

  ** Only flushes a full chunk
  private This flushIfNeeded()
  {
    chunk.size == chunkSize ? flushChunk : this
  }

  private This flushChunk()
  {
    // sanity check
    if (chunk.size > chunkSize) throw IOErr("Chunk grew!")
    if (chunk.isEmpty) return this

    // remember chunk size because it gets cleared
    bytes := chunk.size
    writeChunk(chunk.seek(0))

    // update state
    bytesWritten += bytes
    chunksWritten++
    chunk.clear

    return this
  }

  ** Must be overridden to write the chunk if a wrapped output stream was
  ** not supplied in the constructor.
  protected virtual Void writeChunk(Buf chunk)
  {
    if (out == null) throw IOErr("Not constructed with a wrapped OutStream")
    out.writeBuf(chunk).flush
  }

  ** Flushes any partial chunk and closes the stream (and any wrapped stream)
  override Bool close()
  {
    try
    {
      flushChunk
      this.out?.close
    }
    catch (Err err)
    {
      err.trace
      return false
    }
    return true
  }
}
