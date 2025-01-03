//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  12 Dec 2024  Matthew Giannini Creation
//

using haystack

**
** FolioFile provides APIs associated with storing files in folio. Folio itself
** only stores a rec with information about the file. Implementations will typically
** store the actual file contents to the local filesystem or cloud.
**
@NoDoc
const mixin FolioFile
{
  ** Create a new file in folio. The callback will be invoked with an
  ** `OutStream` that can be used to write contents to the file. The new folio
  ** rec for this file is returned.
  **
  ** pre>
  ** rec := Etc.makeDict(["spec":"File"])
  ** rec = folio.file.create(rec) |out| { out.writeChars("Hello, FolioFile!") }
  ** <pre
  abstract Dict create(Dict rec, |OutStream| f)

  ** Reads the file with the given id. The callback will be invoked with
  ** an `InStream` that can be used to read the file. The result of the callback
  ** is returned.
  **
  ** pre>
  ** contents := folio.file.read(rec.id) |in| { in.readAllStr }
  ** <pre
  abstract Obj? read(Ref id, |InStream->Obj?| f)

  ** Write to an existing file with the given id. The callback will be invoked
  ** with an 'OutStream' that can be used to write contents to the file. The existing
  ** file will be overwritten.
  **
  ** It is an error to call this method for a file id that has not been created yet.
  **
  ** pre>
  ** folio.file.write(rec.id) |out| { out.writeChars("new content") }
  ** <pre
  abstract Void write(Ref id, |OutStream| f)

  ** Clear the contents of the file with the given id (make it 0-bytes).
  abstract Void clear(Ref id)
}

**
** Break out the implementation for local file storage so that
** it can be easily re-used.
**
** Files are hashed into a directory buckets so they aren't all in one
** big directory.
**
@NoDoc
const class LocalFolioFile
{
  new make(Folio folio)
  {
    this.folio = folio
    this.dir = folio.dir.plus(`../files/`)
  }

  const Folio folio
  const File dir

  Dict create(Dict rec, |OutStream| f)
  {
    // get the id
    id := rec.get("id") ?: Ref.gen

    // sanity check that a rec doesn't already exist
    if (folio.readById(id, false) != null) throw ArgErr("Rec with id '${id}' already exists")

    // create the folio rec
    rec = Etc.dictMerge(rec, ["id":Remove.val, "spec": Ref("sys::File")])
    rec = folio.commit(Diff.makeAdd(rec, id)).newRec

    // write the file
    doWrite(id, f)

    // now update the file size
    rec = ((Diff)commitFileSizeAsync(rec).get(30sec)->first).newRec

    // return rec with computed file size
    return rec
  }

  Void write(Ref id, |OutStream| f)
  {
    // do a read to ensure there is a file rec
    rec := folio.readById(id)

    // then we can write it
    doWrite(id, f)

    // commit the change to fileSize async
    commitFileSizeAsync(rec)
  }

  private Void doWrite(Ref id, |OutStream| f)
  {
    out := localFile(id).out
    try
      f(out)
    finally
      out.close
  }

  Obj? read(Ref id, |InStream->Obj?| f)
  {
    // the file must exist
    file := localFile(id)

    // if file doesn't exist use 0-byte input stream
    in := file.exists ? file.in : Buf(0).in
    try
      return f(in)
    finally
      in.close
  }

  Void clear(Ref id)
  {
    // delete the file with the given id in order to "clear" it
    // this works because a read on a non-existent file is 0-byte result
    this.delete(id)

    // update the file size
    rec := folio.readById(id, false)
    if (rec != null) commitFileSizeAsync(rec)
  }

  ** Delete the file on disk
  Void delete(Ref id)
  {
    localFile(id).delete
  }

  ** Utility to compute the file size and commit it to the rec async
  private FolioFuture commitFileSizeAsync(Dict rec)
  {
    folio.commitAsync(Diff(rec, ["fileSize": fileSize(rec.id)], Diff.bypassRestricted))
  }

  ** Get the local file for this id
  private File localFile(Ref id)
  {
    // always use normalized id
    id = norm(id)
    return dir.plus(`b${(id.hash.abs % 1024)}/${id}`)
  }

  ** Get the file size as a Number
  private Number? fileSize(Ref id)
  {
    size := localFile(id).size
    return size == null ? null : Number(size, Number.byte)
  }

  ** normalize the ref for consistency
  private static Ref norm(Ref id) { id.toProjRel }
}
