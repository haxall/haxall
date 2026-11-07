//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Nov 2026  Brian Frank  Creation
//

using util
using xeto
using haystack
using hx

**
** SbomCli generates a CycloneDX software bill of materials
**
internal class SbomCli : HxCli
{
  @Opt { help = "Output file (default is stdout)"; aliases = ["o"] }
  File? out

  @Opt { help = "Scan this install directory instead of the runtime path" }
  File? dir

  @Opt { help = "Output sorted list of package URLs instead of JSON" }
  Bool purls

  override Str name() { "sbom" }

  override Str summary() { "Generate software bill of materials" }

  override Int run()
  {
    sbom := Sbom(dir == null ? Env.cur.path : [dir])
    stream := out?.out ?: Env.cur.out
    try
    {
      if (purls) sbom.purls.each |p| { stream.printLine(p) }
      else sbom.writeJson(stream)
    }
    finally { if (out != null) stream.close; else stream.flush }
    return 0
  }
}

**************************************************************************
** Sbom
**************************************************************************

**
** Sbom generates a CycloneDX software bill of materials by scanning the
** pods, xeto libs, and jars installed under each path directory's lib/.
**
@NoDoc class Sbom
{

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Scan given path directories; first match wins like pod resolution
  new make(File[] path := Env.cur.path)
  {
    this.path = path
    scan
    this.root = makeRoot
  }

  ** Path directories scanned
  const File[] path

  ** Product root component
  SbomComp root { private set }

  ** Components sorted by kind then name
  SbomComp[] comps := [,] { private set }

//////////////////////////////////////////////////////////////////////////
// Scan
//////////////////////////////////////////////////////////////////////////

  private Void scan()
  {
    pods := scanDir(`lib/fan/`, "pod")  |f| { SbomComp.makePod(f) }
    xeto := scanDir(`lib/xeto/`, "xetolib") |f| { SbomComp.makeXeto(f) }
    jars := scanDir(`lib/java/`, "jar") |f| { SbomComp.makeJar(f, pods[f.basename]) }
    comps.addAll(sortVals(pods)).addAll(sortVals(xeto)).addAll(sortVals(jars))
    rootUri := path.first.normalize.uri
    comps.each |c| { c.path = c.file.normalize.uri.relTo(rootUri).toStr }
  }

  ** Scan files with ext in dir under each path directory, first wins
  private Str:SbomComp scanDir(Uri dir, Str ext, |File->SbomComp?| f)
  {
    acc := Str:SbomComp[:]
    path.each |p|
    {
      (p + dir).listFiles.each |file|
      {
        if (file.ext != ext || acc.containsKey(file.basename)) return
        c := f(file)
        if (c != null) acc[file.basename] = c
      }
    }
    return acc
  }

  private static SbomComp[] sortVals(Str:SbomComp map)
  {
    map.vals.sort |a, b| { a.name <=> b.name }
  }

  ** Root is SkySpark if skyarcd is installed, otherwise Haxall
  private SbomComp makeRoot()
  {
    pod := comps.find { it.kind == "pod" && it.name == "skyarcd" }
    if (pod != null) return SbomComp.makeRoot("SkySpark", pod)
    pod = comps.find { it.kind == "pod" && it.name == "hx" }
    if (pod != null) return SbomComp.makeRoot("Haxall", pod)
    throw Err("No skyarcd or hx pod found in path: $path")
  }

//////////////////////////////////////////////////////////////////////////
// Output
//////////////////////////////////////////////////////////////////////////

  ** Sorted unique list of every purl including wrapped upstream libs; a
  ** lib embedded in several pods is listed once
  Str[] purls()
  {
    acc := Str[,]
    comps.each |c| { acc.add(c.purl); c.children.each |k| { acc.add(k.purl) } }
    return acc.unique.sort
  }

  ** Grid with one row per component; wrapped libs follow their pod
  Grid toGrid()
  {
    gb := GridBuilder()
    gb.setMeta(["sbom": root.name + " " + root.version, "sbomFile": fileName])
    gb.addColNames(["purl", "type", "supplier", "license", "file"])
    gb.addCol("sha512", ["hidden": Marker.val])
    comps.each |c|
    {
      gb.addRow(c.toRow)
      c.children.each |k| { gb.addRow(k.toRow) }
    }
    return gb.toGrid
  }

  ** Standard file name such as "skyspark-4.0.7.cdx.json"
  Str fileName() { "${root.name.lower}-${root.version}.cdx.json" }

  ** Write CycloneDX JSON document
  Void writeJson(OutStream out)
  {
    JsonOutStream(out) { it.prettyPrint = true }.writeJson(toJson)
    out.printLine
  }

  ** CycloneDX JSON document as ordered maps for stable output
  [Str:Obj] toJson()
  {
    acc := Str:Obj[:] { ordered = true }
    acc["bomFormat"]    = "CycloneDX"
    acc["specVersion"]  = "1.6"
    acc["version"]      = 1
    acc["metadata"]     = metaJson
    acc["components"]   = comps.map |c->Obj| { c.toJson }
    acc["dependencies"] = depsJson
    return acc
  }

  private [Str:Obj] metaJson()
  {
    acc := Str:Obj[:] { ordered = true }
    if (root.ts != null) acc["timestamp"] = root.ts
    acc["component"] = root.toJson
    acc["manufacturer"] = SbomComp.orgJson("SkyFoundry", "https://skyfoundry.com/")
    acc["supplier"] = SbomComp.orgJson("SkyFoundry", "https://skyfoundry.com/")
    return acc
  }

  ** Dependency graph limited to components present in the scan
  private Obj[] depsJson()
  {
    refs := Str:Str[:]
    comps.each |c| { refs[c.kind + ":" + c.name] = c.ref }
    acc := Obj[,]
    acc.add(dep(root.ref, comps.map |c->Str| { c.ref }))
    comps.each |c|
    {
      acc.add(dep(c.ref, c.depends.map |d->Str?| { refs[c.depKind + ":" + d] }.exclude { it == null }))
    }
    return acc
  }

  private static [Str:Obj] dep(Str ref, Str[] dependsOn)
  {
    acc := Str:Obj[:] { ordered = true }
    acc["ref"] = ref
    acc["dependsOn"] = dependsOn
    return acc
  }
}

**************************************************************************
** SbomComp
**************************************************************************

**
** SbomComp is one component in the bill of materials
**
@NoDoc class SbomComp
{

//////////////////////////////////////////////////////////////////////////
// Factories
//////////////////////////////////////////////////////////////////////////

  ** Make from pod meta.props
  static SbomComp makePod(File f)
  {
    withZip(f) |zip->SbomComp|
    {
      m := readProps(zip, `/meta.props`)
      c := make("pod", m["pod.name"], m["pod.version"], f)
      c.supplier = m["org.name"]
      c.license  = toSpdx(m["license.name"])
      c.depends  = toDepNames(m["pod.depends"])
      c.purl     = "pkg:generic/fantom/${c.name}@${c.version}"
      c.ts       = DateTime.fromStr(m["build.ts"] ?: "", false)?.toIso
      c.initWrapped(m["sbom.purl"] ?: detectMaven(zip, c.license))
      return c
    }
  }

  ** Make from xetolib xeto-meta.props and xeto-build.props
  static SbomComp makeXeto(File f)
  {
    withZip(f) |zip->SbomComp|
    {
      m := readProps(zip, `/xeto-meta.props`)
      b := readProps(zip, `/xeto-build.props`)
      c := make("xeto", m["name"], m["version"], f)
      c.supplier = suffixVal(b, ".org.dis")
      c.license  = toSpdx(suffixVal(b, ".license"))
      c.depends  = toDepNames(m["depends"])
      c.purl     = "pkg:generic/xeto/${c.name}@${c.version}"
      return c
    }
  }

  ** Detect Maven libs unpacked into a pod without sbom.purl meta from their
  ** pom.properties, else from jar manifest Implementation fields; they are
  ** assumed to share the pod's license.  Return sbom.purl style list.
  private static Str? detectMaven(Zip zip, Str license)
  {
    acc := Str[,]
    zip.contents.each |f, uri|
    {
      if (uri.name != "pom.properties" || uri.path.getSafe(1) != "maven") return
      p := f.readProps
      acc.add(mavenEntry(p["groupId"], p["artifactId"], p["version"], license))
    }
    if (acc.isEmpty)
    {
      mf := Str:Str[:]
      zip.contents[`/META-INF/MANIFEST.MF`]?.readAllLines?.each |line|
      {
        i := line.index(": ")
        if (i != null) mf[line[0..<i]] = line[i+2..-1].trim
      }
      acc.add(mavenEntry(mf["Implementation-Vendor-Id"], mf["Implementation-Title"], mf["Implementation-Version"], license))
    }
    acc = acc.exclude { it.isEmpty }.sort
    return acc.isEmpty ? null : acc.join(", ")
  }

  private static Str mavenEntry(Str? group, Str? artifact, Str? ver, Str license)
  {
    group == null || artifact == null || ver == null ? "" : "pkg:maven/$group/$artifact@$ver $license"
  }

  ** Make jar from the pod of the same name such as sys.jar for sys.pod
  static SbomComp? makeJar(File f, SbomComp? pod)
  {
    if (pod == null) return null
    c := make("jar", f.name, pod.version, f)
    c.supplier = pod.supplier
    c.license  = pod.license
    c.purl     = "pkg:generic/fantom/${f.name}@${c.version}"
    return c
  }

  ** Make product root component from its main pod
  static SbomComp makeRoot(Str product, SbomComp pod)
  {
    c := make("app", product, pod.version, null)
    c.supplier = "SkyFoundry"
    c.purl     = "pkg:generic/skyfoundry/${product.lower}@${c.version}"
    c.ts       = pod.ts
    return c
  }

  ** Make wrapped upstream lib from "<purl> [<license>]"; supplier is
  ** the purl namespace such as "org.slf4j", or the name if none
  private static SbomComp makeWrapped(SbomComp pod, Str entry)
  {
    toks := entry.split(' ').exclude { it.isEmpty }
    purl := toks.first
    path := purl[purl.index("/")+1..-1].split('?').first.split('#').first.split('/')
    name := path.last
    ver  := name.contains("@") ? name[name.index("@")+1..-1] : null
    if (ver != null) name = name[0..<name.index("@")]
    c := make("wrapped", name, ver, null)
    c.ref      = pod.ref + "/" + name
    c.purl     = purl
    c.supplier = path.size > 1 ? path[-2] : name
    c.license  = toks.getSafe(1)
    return c
  }

  private new make(Str kind, Str name, Str? version, File? file)
  {
    this.kind     = kind
    this.name     = name
    this.version  = version
    this.ref      = kind + ":" + name
    this.file     = file
    this.filename = file?.name
    if (file != null) initFile(file)
  }

  private Void initFile(File f)
  {
    this.sha512 = f.readAllBuf.toDigest("SHA-512").toHex
  }

  ** Third party libs packaged unmodified by the pod become children
  private Void initWrapped(Str? list)
  {
    if (list == null) return
    this.children = list.split(',').exclude { it.isEmpty }.map |e->SbomComp| { makeWrapped(this, e) }
  }

//////////////////////////////////////////////////////////////////////////
// Fields
//////////////////////////////////////////////////////////////////////////

  ** Kind: pod, xeto, jar, app, or wrapped
  const Str kind

  ** Component name
  const Str name

  ** Component version
  const Str? version

  ** CycloneDX bom-ref
  Str ref { private set }

  ** Package URL
  Str purl := "" { private set }

  ** File name for deployable components
  const Str? filename

  ** Deployable file
  const File? file

  ** File path relative to the scan root such as "lib/fan/sys.pod"; used
  ** in JSON so output is the same wherever an install is unzipped
  Str? path { internal set }

  ** SHA-512 hex of deployable file
  Str? sha512 { private set }

  ** Supplier organization name
  Str? supplier { private set }

  ** SPDX license id or free text name
  Str? license { private set }

  ** Names of components this depends on
  Str[] depends := Str[,] { private set }

  ** Build timestamp as ISO string
  Str? ts { private set }

  ** Wrapped upstream libs
  SbomComp[] children := SbomComp[,] { private set }

  ** Display type: pod, xetolib, jar, or lib for wrapped libs
  Str typeDis()
  {
    switch (kind)
    {
      case "xeto":    return "xetolib"
      case "wrapped": return "lib"
      default:        return kind
    }
  }

  ** Kind of components named in depends
  Str depKind() { kind == "xeto" ? "xeto" : "pod" }

//////////////////////////////////////////////////////////////////////////
// Output
//////////////////////////////////////////////////////////////////////////

  ** Grid row cells in toGrid column order
  Obj?[] toRow()
  {
    [purl, typeDis, supplier, license, file?.osPath, sha512]
  }

  ** CycloneDX component JSON
  [Str:Obj] toJson()
  {
    acc := Str:Obj[:] { ordered = true }
    acc["type"] = kind == "app" ? "application" : "library"
    acc["bom-ref"] = ref
    if (supplier != null) acc["supplier"] = ["name": supplier]
    acc["name"] = name
    if (version != null) acc["version"] = version
    if (license != null) acc["licenses"] = [licenseJson]
    acc["purl"] = purl
    if (sha512 != null) acc["externalReferences"] = [distJson]
    if (filename != null) acc["properties"] = propsJson
    if (!children.isEmpty) acc["components"] = children.map |c->Obj| { c.toJson }
    return acc
  }

  private [Str:Obj] licenseJson()
  {
    lic := Str:Obj[:] { ordered = true }
    if (isSpdx(license)) lic["id"] = license
    else lic["name"] = license
    return ["license": lic]
  }

  private [Str:Obj] distJson()
  {
    acc := Str:Obj[:] { ordered = true }
    acc["type"] = "distribution"
    acc["url"] = path
    acc["hashes"] = [["alg": "SHA-512", "content": sha512]]
    return acc
  }

  ** BSI TR-03183-2 required component properties
  private Obj[] propsJson()
  {
    [prop("bsi:component:filename",   filename),
     prop("bsi:component:executable", kind == "xeto" ? "non-executable" : "executable"),
     prop("bsi:component:archive",    "archive"),
     prop("bsi:component:structured", "structured")]
  }

  private static [Str:Obj] prop(Str name, Str val)
  {
    acc := Str:Obj[:] { ordered = true }
    acc["name"] = name
    acc["value"] = val
    return acc
  }

  ** Organization JSON for metadata manufacturer and supplier
  static [Str:Obj] orgJson(Str name, Str uri)
  {
    acc := Str:Obj[:] { ordered = true }
    acc["name"] = name
    acc["url"] = [uri]
    return acc
  }

//////////////////////////////////////////////////////////////////////////
// Utils
//////////////////////////////////////////////////////////////////////////

  private static Obj? withZip(File f, |Zip->Obj?| cb)
  {
    zip := Zip.open(f)
    try
      return cb(zip)
    finally
      zip.close
  }

  private static Str:Str readProps(Zip zip, Uri uri)
  {
    zip.contents[uri]?.readProps ?: throw Err("Missing $uri in $zip.file")
  }

  ** Value of first key with given suffix such as "hx.license"
  private static Str? suffixVal(Str:Str props, Str suffix)
  {
    props.find |v, k| { k.endsWith(suffix) }
  }

  ** Parse "sys 1.0;util 1.0" into names
  private static Str[] toDepNames(Str? depends)
  {
    if (depends == null || depends.isEmpty) return Str[,]
    return depends.split(';').map |d->Str| { d.split(' ').first }.unique
  }

  ** Map license names used in pod meta to SPDX ids; our own pods and
  ** libs which do not declare a license default to Commercial
  private static Str toSpdx(Str? name)
  {
    n := name ?: "Commercial"
    return spdxNames[n] ?: n
  }

  private static const Str:Str spdxNames := [
    "Academic Free License 3.0": "AFL-3.0",
    "Apache 2.0": "Apache-2.0",
    "Commercial": "LicenseRef-SkyFoundry-Commercial",
  ]

  ** Is name an SPDX list id such as AFL-3.0 rather than free text; custom
  ** LicenseRef ids are not allowed as CycloneDX license ids
  private static Bool isSpdx(Str name)
  {
    !name.startsWith("LicenseRef-") && name.all |ch| { ch.isAlphaNum || ch == '-' || ch == '.' || ch == '+' }
  }
}

