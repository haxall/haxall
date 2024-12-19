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

  ** Delete the folio rec and file with the given id. Returns a `FolioFuture`
  ** that will be completed after both the file and rec have been deleted.
  **
  ** pre>
  ** folio.file.delete(rec.id).get
  ** <pre
  abstract FolioFuture delete(Ref id)
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
    // create the folio rec for this file
    id := rec.get("id") ?: Ref.gen
    rec = Etc.dictRemove(rec, "id")
    rec = Etc.dictSet(rec, "spec", "File")
    rec = folio.commit(Diff.makeAdd(rec, id)).newRec

    // now write the file
    doWrite(id, f)

    // return the newly created folio rec
    return rec
  }

  Void write(Ref id, |OutStream| f)
  {
    // do a read to ensure there is a file rec (TODO: validation?)
    rec := folio.readById(id)

    // then we can write it
    doWrite(id, f)
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
    if (!file.exists) throw ArgErr("File not found: ${file.name}")

    // read it
    in := file.in
    try
      return f(in)
    finally
      in.close
  }

  Void delete(Ref id)
  {
    // remove the rec if file delete successful
    rec := folio.readById(id, false)
    if (rec != null) folio.commit(Diff(rec, null, Diff.remove))

    // then delete the file in local file system
    localFile(id).delete
  }

  ** Get the local file for this id
  private File localFile(Ref id)
  {
    // always use normalized id
    id = norm(id)
    return dir.plus(`b${(id.hash.abs % 1024)}/${id}`)
  }

  ** normalize the ref for consistency
  private static Ref norm(Ref id) { id.toProjRel }
}
