//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  19 Dec 2024  Matthew Giannini Creation
//

using haystack
using folio

@NoDoc
const class FileMgr : HxFolioMgr, FolioFile
{
  new make(HxFolio folio) : super(folio)
  {
    this.file = LocalFolioFile(folio)
  }

  private const LocalFolioFile file

  override Dict create(Dict rec, |OutStream| f)
  {
    // TODO: should we do spec validation; if so how?
    // create the folio rec for this file. force it to have File spec
    id := rec.get("id") ?: Ref.gen
    rec = Etc.dictRemove(rec, "id")
    rec = Etc.dictSet(rec, "spec", "File")
    rec = folio.commit(Diff.makeAdd(rec, id)).newRec

    // create the local file
    file.write(id, f)

    // return the newly created folio rec
    return rec
  }

  override Obj? read(Ref id, |InStream->Obj?| f)
  {
    file.read(id, f)
  }

  override Void write(Ref id, |OutStream| f)
  {
    // TODO: spec validation?
    // ensure there is a rec in folio with this id
    rec := folio.readById(id)

    // then we can write it
    file.write(id, f)
  }

  override FolioFuture delete(Ref id)
  {
    FolioFuture.makeAsync(send(Msg(MsgId.fileDelete, id)))
  }

  override internal Obj? onReceive(Msg msg)
  {
    switch (msg.id)
    {
      case MsgId.fileDelete: return onDelete(msg.a)
    }
    return super.onReceive(msg)
  }

  private Obj? onDelete(Ref id)
  {
    // delete the file itself first
    file.delete(id)

    // remove the rec if file delete successful
    rec := folio.readById(id, false)
    if (rec != null) folio.commit(Diff(rec, null, Diff.remove))

    return FileDeleteRes(id)
  }
}