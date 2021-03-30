//
// Copyright (c) 2018, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   25 Jul 2018  Brian Frank  Creation
//    9 Jan 2019  Brian Frank  Redesign
//

using compilerDoc
using web
using haystack
using def

**
** Generate HTML documentation
**
internal class GenDocs : DefCompilerStep
{
  new make(DefCompiler c) : super(c) {}


  override Void run()
  {
    // init directory
    numFiles := 0

    // setup onFile callback - for now we just write to disk, but
    // for project-haystack.org we will cache in memory
    onFile := compiler.onDocFile
    if (onFile != null)
    {
      info("Generating in-memory")
      genFullHtml = false
    }
    else
    {
      dir := compiler.initOutDir
      info("Generating docs [$dir.osPath]")
      genFullHtml = true
      onFile = |DocFile f|
      {
        numFiles++
        local := dir + f.uri
        //info("  Generating: $local.osPath")
        out := local.out.writeBuf(f.content).close
      }
    }

    // render all the documents, copy resource files
    render(docEnv.topIndex, onFile)
    copy(typeof.pod.file(`/res/css/style.css`), `style.css`, onFile)
    docEnv.spacesMap.each |space|
    {
      space.eachDoc |doc| { render(doc, onFile) }
    }
    resFiles.each |res| { copyResFile(res, onFile) }

    info("Generated docs [$numFiles files]")
  }

  private Void render(Doc doc, |DocFile| onFile)
  {
    // we don't use compilerDoc DocRes, but rather our own
    // local DocResFile with error checking and more pluggability
    if (doc is DocRes) return

    // build path uri for document
    s := StrBuf()
    if (doc.isTopIndex)
      s.add("index")
    else
      s.add(doc.space.spaceName).addChar('/').add(doc.docName)
    if (docEnv.linkUriExt != null) s.add(docEnv.linkUriExt)
    uri := s.toStr.toUri

    // render to a memory buffer
    buf := Buf(1024)
    out := DocOutStream(buf.out, resFiles)
    docEnv.render(out, doc)

    // callback
    onFile(DocFile(uri, doc.title, buf))
  }

  private Void copyResFile(DocResFile res, |DocFile| onFile)
  {
    uri := (res.spaceName + "/" + res.docName).toUri
    onFile(DocFile(uri, uri.name, res.file.readAllBuf))
  }

  private Void copy(File src, Uri uri, |DocFile| onFile)
  {
    buf := src.readAllBuf
    onFile(DocFile(uri, uri.name, buf))
  }

  Bool genFullHtml
  Str:DocResFile resFiles := [:]
}

**************************************************************************
** DocFile
**************************************************************************

const class DocFile
{
  new make(Uri uri, Str title, Buf content)
  {
    this.uri = uri
    this.title = title
    this.content = content
  }

  const Uri uri
  const Str title
  const Buf content
}

**************************************************************************
** DocResFile
**************************************************************************

const class DocResFile
{
  new make(Str spaceName, Str docName, File file)
  {
    this.spaceName = spaceName
    this.docName = docName
    this.file = file
    this.qname = spaceName + "::" + docName
  }
  const Str spaceName
  const Str docName
  const Str qname
  const File file
  override Str toStr() { qname }
}


