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
    file.create(rec, f)
  }

  override Obj? read(Ref id, |InStream->Obj?| f)
  {
    file.read(id, f)
  }

  override Void write(Ref id, |OutStream| f)
  {
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
    file.delete(id)
    return FileDeleteRes(id)
  }
}