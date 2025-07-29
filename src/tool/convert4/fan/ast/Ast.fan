//
// Copyright (c) 2025, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Jul 2025  Brian Frank  Creation
//

using util
using haystack
using axon

**
** AST root
**
class Ast
{

  This scanWorkDir()
  {
    scanFile(Env.cur.workDir)
  }

  /* this code uses SkySpark SysNamespace
  This scanSysDef()
  {
    boot := Boot()
    sys := boot.init
    libs := Lib[,]
    sys.installed.libs.each |lib|
    {
      n := lib.name
      if (lib.has("sysMod")) libs.add(lib)
    }

    libs.sort
    pods := Str:APod[:]
    libs.each |lib|
    {
      typeName := lib->typeName.toStr
      podName := typeName[0..<typeName.index("::")]
      specName := typeName[typeName.index("::") + 2 .. -1]
      if (specName.startsWith("Std")) specName = specName[3..-1]
      if (specName.endsWith("Lib")) specName = specName[0..-4] + "Ext"
      if (specName.endsWith("Mod")) specName = specName[0..-4] + "Ext"

      dict := Etc.dictRemoveAll(lib, ["depends", "doc"])

      pod := pods[podName]
      if (pod == null) pods[podName] = pod = APod(this, podName, null, null)

      oldName := lib.name
      newName := "hx." + oldName.lower
      ext := AExt(this, pod, oldName, specName, AExtType.mod, (Dict)lib)
      pod.exts.add(ext)

      sys.installed.funcs.each |f|
      {
        if (f.name == "compTester") return
        if (f.lib === lib)
        {
          ff := (FantomFn)f.expr
          af := AFunc.reflectMethod(ff.method, f)
          ext.funcs.add(af)
        }
      }

    }
    this.pods.addAll(pods.vals)

    return this
  }
  */

  private This scanFile(File f)
  {
    try
    {
      if (f.name == "build.fan") pods.addNotNull(APod.scan(this, f))
      if (f.isDir) f.list.each |sub| { scanFile(sub) }
    }
    catch (Err e)
    {
      Console.cur.err("Cannot scan dir [$f.osPath]", e)
    }
    return this
  }

  const File xetoSrcDir := Env.cur.workDir + `src/xeto/`

  AConfig config := AConfig.load

  APod[] pods := [,]

  AExt[] exts()
  {
    acc := AExt[,]
    pods.each |pod| { acc.addAll(pod.exts) }
    acc.sort
    return acc
  }

//////////////////////////////////////////////////////////////////////////
// Tables
//////////////////////////////////////////////////////////////////////////

  Str[][] podsTable()
  {
    rows := Str[][,]
    rows.add(["name", "ext", "type", "dir", "fantomFuncs"])
    pods.each |pod|
    {
      pod.exts.each |ext|
      {
        rows.add([pod.name, ext.oldName, ext.type, pod.dir, ext.fantomFuncType])
      }
    }
    return rows
  }

  Str[][] extsTable()
  {
    rows := Str[][,]
    rows.add(["oldName", "libName", "type"])
    exts.each |ext|
    {
      rows.add([ext.oldName, ext.libName, ext.type.name])
    }
    return rows
  }

  Str[][] funcsTable()
  {
    rows := Str[][,]
    rows.add(["qname", "sig"])
    exts.each |ext|
    {
      ext.funcs.each |f|
      {
        qname := ext.oldName + "::" + f.name
        rows.add([qname, f.sig])
      }
    }
    return rows
  }

//////////////////////////////////////////////////////////////////////////
// Dumps
//////////////////////////////////////////////////////////////////////////

  Void dump(Console con := Console.cur)
  {
    dumpPods(con)
    dumpExts(con)
    dumpFuncs(con)
  }

  Void dumpPods(Console con := Console.cur)
  {
    con.info("")
    con.info("### Pods [$pods.size] ###")
    con.table(podsTable)
  }

  Void dumpExts(Console con := Console.cur)
  {
    con.info("")
    con.info("### Exts [$exts.size] ###")
    con.table(extsTable)
  }

  Void dumpFuncs(Console con := Console.cur)
  {
    con.info("")
    con.info("### Funcs ###")
    con.table(funcsTable)
  }

}

