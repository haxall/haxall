//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  19 Dec 2024  Matthew Giannini Creation
//

using concurrent
using haystack
using folio

**
** FileMgrTest
**
class FileMgrTest : WhiteboxTest
{
  Void test()
  {
    open

    id := Ref("test-file")
    byte := Number.byte
    rec := Etc.makeDict([
      "id":   id,
      "mime": "text/plain",
      "spec": Ref("sys::File"),
    ])

    // create
    text := "this is a file!"
    rec = folio.file.create(rec) |OutStream out| { out.writeChars(text) }
    verifyEq(rec.id, id)
    verifyEq(n(text.size, byte), rec["fileSize"])
    verifyEq(text, folio.file.read(id) |in| { in.readAllStr })

    // write
    text = "modified!"
    folio.file.write(id) |out| { out.writeChars(text) }
    folio.sync
    verifyEq(n(text.size, byte), folio.readById(id)["fileSize"])
    verifyEq(text, folio.file.read(id) |in| { in.readAllStr })

    // clear
    folio.file.clear(id)
    folio.sync
    verifyEq(Number(0, byte), folio.readById(id)["fileSize"])
    verifyEq("", folio.file.read(id) |in| { in.readAllStr })

    // removing the rec deletes the file.
    // making use of internal implementation details to verify this. see LocalFolioFile
    filesDir := folio.dir.plus(`../files/`)
    try
    {
      count := 0
      text   = "delete me"
      folio.file.write(id) |out| { out.writeChars(text) }
      folio.sync
      verifyEq(n(text.size, byte), folio.readById(id)["fileSize"])
      verifyEq(text, folio.file.read(id) |in| { in.readAllStr })
      filesDir.walk |f| { if (!f.isDir) ++count }
      verify(count > 0)
      folio.commit(Diff(folio.readById(id), null, Diff.remove))
      folio.sync
      count = 0
      filesDir.walk |f| { if (!f.isDir) ++count }
      verifyEq(0, count)
    }
    finally filesDir.delete

    // reading a file that doesn't exist should be 0 bytes
    verifyEq(0, folio.file.read(Ref("does-not-exist")) |in| { in.readAllBuf }->size)
  }
}