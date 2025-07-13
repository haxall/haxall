//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   13 Aug 2021  Brian Frank  Creation
//

using concurrent
using haystack
using axon
using obs
using folio
using hx

**
** ServiceTest
**
class ServiceTest : HxTest
{

//////////////////////////////////////////////////////////////////////////
// Registry
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testRegistry()
  {
    // not found stuff
//    verifyServiceNotFound(Str#)

    // verify HxStdServices
// TODO
//    verifySame(rt.obs,   rt.services.obs);   verifySame(verifyService(HxObsService#), rt.obs)
//    verifySame(rt.watch, rt.services.watch); verifySame(verifyService(WatchService#), rt.watch)
//    verifySame(rt.user,  rt.services.user);  verifySame(verifyService(HxUserService#), rt.user)

/*
    // pointWrite defaults to nil implementation
    if (rt.libs.get("hx.point", false) != null) rt.libs.remove("hx.point")
    verifySame(rt.pointWrite.typeof, NilPointWriteService#)
    verifySame(rt.pointWrite, rt.services.pointWrite)
    verifySame(verifyService(HxPointWriteService#), rt.pointWrite)

    // add point lib and ensure it becomes implementation
    rt.libs.add("hx.point")
    verifyNotNull(rt.libs.get("hx.point", false))
    verifySame(rt.pointWrite.typeof.name, "WriteMgrActor")
    verifySame(rt.pointWrite, rt.services.pointWrite)
    verifySame(verifyService(HxPointWriteService#), rt.pointWrite)

    // remove point lib and pointWrite falls back to nil implementation
    rt.libs.remove("hx.point")
    verifyNull(rt.libs.get("hx.point", false))
    verifySame(rt.pointWrite.typeof, NilPointWriteService#)
    verifySame(rt.pointWrite, rt.services.pointWrite)
    verifySame(verifyService(HxPointWriteService#), rt.pointWrite)
*/
fail
  }

/*
  Obj verifyService(Type t)
  {
    service := rt.services.get(t)
    verifyEq(rt.services.getAll(t).containsSame(service), true)
    verifyEq(rt.services.list.containsSame(t), true)

    grid := (Grid)eval("services()")
    verifyNotNull(grid.find |r| { r->type == t.qname })

    return service
  }

  Void verifyServiceNotFound(Type t)
  {
    verifyEq(rt.services.get(t, false), null)
    verifyEq(rt.services.getAll(t), HxService[,])
    verifyErr(UnknownServiceErr#) { rt.services.get(t) }
    verifyErr(UnknownServiceErr#) { rt.services.get(t, true) }

    grid := (Grid)eval("services()")
    verifyNull(grid.find |r| { r->type == t.qname })
  }
*/

//////////////////////////////////////////////////////////////////////////
// File
//////////////////////////////////////////////////////////////////////////

  @HxRuntimeTest
  Void testFile()
  {
    rt.dir.plus(`io/`).create

    // "io/"
    f := verifyFileResolve(`io/`, true)
    verifyEq(f.isDir, true)
    verifyEq(f.list, File[,])
    if (rt.platform.isSkySpark)
      verifyEq(f.parent.uri, `/proj/${rt.name}/`)
    else
      verifyEq(f.parent, null)

    // "io/a.txt"
    f = verifyFileResolve(`io/a.txt`, false)
    verifyEq(f.exists, false)
    f.create
    verifyEq(f.exists, true)
    verifyEq(f.size, 0)
    verifyEq(f.parent.uri, normUri(`io/`))
    verifyEq(f.readAllStr, "")
    f.out.print("hi").close
    verifyEq(f.size, 2)
    verifyEq(f.readAllStr, "hi")
    verifyFileResolve(`io/a.txt`, true)

    // "io/sub"
    f = verifyFileResolve(`io/sub/`, false)
    f.create
    verifyEq(f.exists, true)
    verifyEq(f.size, null)
    verifyEq(f.isDir, true)

    // "io/" listing
    f = verifyFileResolve(`io/`, true)
    list := f.list.dup.sort |a, b| { a.name <=> b.name }
    verifyEq(list.size, 2)
    verifyEq(list[0].uri, normUri(`io/a.txt`))
    verifyEq(list[1].uri, normUri(`io/sub/`))

    // various bad URIs
    verifyFileUnsupported(`bad.txt`)
    verifyFileUnsupported(`io/../bad.txt`)
  }

  File verifyFileResolve(Uri uri, Bool exists)
  {
    f := rt.exts.file.resolve(uri)
    verifyEq(f.uri, normUri(uri))
    verifyEq(f.isDir, uri.isDir)
    verifyEq(f.exists, exists)
    return f
  }

  Uri normUri(Uri uri)
  {
    if (uri.toStr.startsWith("io/"))
    {
      return rt.platform.isSkySpark ? "/proj/${rt.name}/${uri}".toUri : uri
    }
    return uri
  }

  Void verifyFileUnsupported(Uri uri)
  {
    try
    {
      f := rt.exts.file.resolve(uri)
      verify(!f.exists)
    }
    catch (UnsupportedErr e)
    {
      verify(true)
    }
  }

}

