//
// Copyright (c) 2024, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//  19 Dec 2024  Matthew Giannini Creation
//

using concurrent
using xeto
using haystack
using folio

**
** FileMgrTest
**
class FileMgrTest : WhiteboxTest
{
  static const Unit byte := Number.byte

  Void test()
  {
    ns := XetoEnv.cur.createNamespaceFromNames(["sys", "sys.files"])

    open
    folio.hooks = FileTestHooks(ns)

    id := Ref("test-file")
    rec := addRec([
      "id":   id,
      "spec": Ref("sys.files::PlainTextFile"),
    ])

    // init and force the file to be empty
    file := folio.file.get(rec.id, false)
    verifyNotNull(file)
    file.delete
    verifyFalse(file.exists)

    // writes
    verifyWrite(id, "this is a file!")
    verifyWrite(id, "modified!")

    // mimeType
    verifyEq(file.mimeType, MimeType.forExt("txt"))

    // reading a deleted file throws IOErr
    file.delete
    verifyFalse(file.exists)
    verifyErr(IOErr#) { file.withIn |in| { in.readAllStr } }

    // removing the rec also removes the backing file
    file = verifyWrite(id, "now i'm gonna delete the rec")
    folio.commit(Diff(folio.readById(id), null, Diff.remove))
    folio.sync
    verifyFalse(file.exists)
    verifyNull(folio.file.get(id, false))
  }

  private File verifyWrite(Ref id, Str text)
  {
    file := folio.file.get(id)
    file.withOut |out| { out.writeChars(text) }
    folio.sync
    rec  := readById(id)
    verify(file.exists)
    verifyEq(n(text.size, byte), rec["fileSize"])
    verifyEq(text, file.withIn |in| { in.readAllStr })
    return file
  }
}

const class FileTestHooks : FolioHooks
{
  new make(Namespace ns) { nsRef = ns }

  override Namespace? ns(Bool checked := true) { nsRef }
  const Namespace nsRef

  override DefNamespace? defs(Bool checked := true) { if (checked) throw UnsupportedErr("Namespace not availble"); return null }
  override Void preCommit(FolioCommitEvent event) {}
  override Void postCommit(FolioCommitEvent event) {}
  override Void postHisWrite(FolioHisEvent event) {}
}

