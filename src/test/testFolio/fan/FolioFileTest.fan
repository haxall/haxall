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

class FolioFileTest : AbstractFolioTest
{
  static const Unit byte := Number.byte
  Namespace? ns

  override Void setup()
  {
    this.ns = XetoEnv.cur.createNamespaceFromNames(["sys", "sys.files"])
  }

  Void testFile() { runImpls }
  Void doTestFile()
  {
    if (!impl.supportsFile) return

    folio := open
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
    verifyFalse(file.isDir)

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

    // verify trashing rec
    rec = addRec([
      "id": id,
      "spec": Ref("sys.files::PlainTextFile"),
    ])

    // moving the file to trash does not remove backing file
    file = verifyWrite(id, "now i'm gonna delete the rec")
    folio.commit(Diff(folio.readById(id), ["trash":Marker.val]))
    folio.sync
    verify(file.exists)

    // emptying trash does remove backing file
    folio.commitRemoveTrashAsync.get(5sec)
    verifyFalse(file.exists)
    verifyNull(folio.file.get(id, false))
  }

  Void testDir() { runImpls }
  Void doTestDir()
  {
    if (!impl.supportsFile) return

    folio := open
    // force files/ directory to be clean
    folio.dir.plus(`../files/`).delete
    folio.hooks = FileTestHooks(ns)

    id := Ref("conversation-1")
    rec := addRec([
      "id":   id,
      "spec": Ref("sys.files::FileDir"),
    ])

    // init
    file := folio.file.get(rec.id, false)
    verifyNotNull(file)
    file.delete
    verifyFalse(file.exists)
    verify(file.isDir)
    verify(file.list.isEmpty)

    // create the dir
    file.create
    verify(file.exists)

    // create a file
    a := file.plus(`a.txt`)
    a.out.writeChars("a").close
    verify(a.exists)
    verifyEq("a", a.in.readAllStr)

    // list files
    files := file.list
    verifyEq(files.size, 1)
    verifyEq(files.first, a)

    // delete directory
    file.delete
    verifyFalse(file.exists)
    verifyFalse(a.exists)

    // removing the rec also delete the backing directory
    a.out.writeChars("a").close
    verify(file.exists)
    verify(a.exists)
    verifyEq("a", a.in.readAllStr)
    folio.commit(Diff(folio.readById(id), null, Diff.remove))
    folio.sync
    verifyFalse(file.exists)
    verifyFalse(a.exists)
    verifyNull(folio.file.get(id, false))

    // verify trashing rec
    rec = addRec([
      "id": id,
      "spec": Ref("sys.files::FileDir"),
    ])

    // moving the file to trash does not remove backing file or sub-files
    a.out.writeChars("a").close
    verify(file.exists)
    verify(a.exists)
    verifyEq("a", a.in.readAllStr)
    folio.commit(Diff(folio.readById(id), ["trash":Marker.val]))
    folio.sync
    verify(file.exists)
    verify(a.exists)
    verifyEq("a", a.in.readAllStr)

    // emptying trash does remove backing file and sub-files
    folio.commitRemoveTrashAsync.get(5sec)
    verifyFalse(file.exists)
    verifyFalse(a.exists)
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