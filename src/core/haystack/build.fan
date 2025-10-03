#! /usr/bin/env fan
//
// Copyright (c) 2008, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   12 Dec 08  Brian Frank  Creation
//    2 Oct 12  Brian Frank  Rename folio -> haystack
//

using build

**
** Build: haystack
**
class Build : BuildPod
{
  new make()
  {
    podName = "haystack"
    summary = "Haystack model and client API"
    meta    = ["org.name":     "SkyFoundry",
               "org.uri":      "https://skyfoundry.com/",
               "proj.name":    "Haxall",
               "proj.uri":     "https://haxall.io/",
               "license.name": "Academic Free License 3.0",
               "vcs.name":     "Git",
               "vcs.uri":      "https://github.com/haxall/haxall",
               "hx.docFantom": "true",
               ]
    depends = ["sys @{fan.depend}",
               "concurrent @{fan.depend}",
               "util @{fan.depend}",
               "inet @{fan.depend}",
               "xeto @{hx.depend}",
               "web @{fan.depend}"]
    srcDirs = [`fan/`]
    jsDirs  = [`js/`]
    resDirs = [`res/`, `locale/`]
  }

  @Target
  Void genBrioConstJs()
  {
    f := scriptDir + `res/brio-consts.txt`
    lines := f.readAllLines
    ver := lines.removeAt(0).split(':')[1].trim
    lines = lines.findAll |line| { !line.trim.isEmpty && !line.startsWith("//") }
    buf := StrBuf().add("\"")
    lines.each |line, i|
    {
      sp  := line.index(" ")
      id  := line[0..<sp]
      val := line[sp+1..-1]
      if (id.toInt - 1 != i) throw Err("line $i = $id")
      if (val.contains("\"") || val.contains("|")) throw Err("val = $val.toCode")
      if (i > 0) buf.add("|")
      buf.add(val)
    }
    buf.add("\"")

    out := scriptDir.plus(`es/BrioConstsFile.js`).out
    out.print("class BrioConstsFile extends sys.Obj {\n")
    out.print("  constructor() { super(); }\n")
    out.print("  typeof() { return BrioConstsFile.type\$; }\n")
    out.print("  static version() { return $ver.toCode; }\n");
    out.print("  static file() { return ").print(buf).print("; }\n");
    out.print("}\n")
    out.close

    out = scriptDir.plus(`js/BrioConstsFile.js`).out
    out.print("fan.haystack.BrioConstsFile = fan.sys.Obj.\$extend(fan.sys.Obj);\n")
    out.print("fan.haystack.BrioConstsFile.prototype.\$ctor = function() {}\n")
    out.print("fan.haystack.BrioConstsFile.prototype.\$typeof = function() { return fan.haystack.BrioConstsFile.\$type; }\n")
    out.print("fan.haystack.BrioConstsFile.version = function() { return $ver.toCode; }\n")
    out.print("fan.haystack.BrioConstsFile.file = function() { throw \"unsupported in js\" }\n")
    out.close
  }
}

