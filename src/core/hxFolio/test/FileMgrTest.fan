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
    rec := Etc.makeDict([
      "id":    id,
      "mime": "text/plain",
      "spec": "File",
    ])
    rec = folio.file.create(rec) |OutStream out| {
      out.writeChars("this is a file!")
    }
    verifyEq(rec.id, id)

    verifyEq("this is a file!",
      folio.file.read(id) |in| { in.readAllStr })

    folio.file.write(id) |out| { out.writeChars("modified!") }
    verifyEq("modified!",
      folio.file.read(id) |in| { in.readAllStr })

    folio.file.delete(id).get
    verifyErr(ArgErr#) { folio.file.read(id) |in| { null } }
    verifyErr(ArgErr#) { folio.file.read(Ref("does-not-exist")) |in| { null } }
  }
}