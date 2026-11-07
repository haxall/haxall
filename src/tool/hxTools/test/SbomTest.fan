//
// Copyright (c) 2026, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   7 Nov 2026  Brian Frank  Creation
//

using util

**
** SbomTest
**
class SbomTest : Test
{
  Void test()
  {
    // two path dirs; second has older hx and a pod hidden by the first
    a := tempDir + `a/`
    b := tempDir + `b/`
    writePod(a, "hx", "4.0.9", "Academic Free License 3.0", "sys 1.0;sys 1.0", null)
    writePod(a, "sys", "1.0.84", "Academic Free License 3.0", null, null)
    writePod(a, "codemirror", "4.0.9", "Commercial", "sys 1.0",
      "pkg:npm/codemirror@5.48.0 MIT, pkg:github/google/diff-match-patch@abc Apache-2.0")
    writePod(b, "hx", "4.0.1", "Commercial", null, null)
    writePod(b, "slf4j_nop", "1.7.25", "Apache 2.0", null, "pkg:maven/org.slf4j/slf4j-api@1.7.25 MIT")
    writeXeto(a, "ph.points", "5.0.0", "sys 5.0.0", ["ph.org.dis": "Project Haystack", "ph.license": "AFL-3.0"])
    writeXeto(a, "hx.foo", "4.0.9", null, ["skyspark.org.dis": "SkyFoundry"])
    writeFile(a + `lib/java/sys.jar`, "jar")
    writeFile(a + `lib/java/orphan.jar`, "jar")

    s := Sbom([a, b])

    // root is Haxall from first hx in path
    verifyEq(s.root.name, "Haxall")
    verifyEq(s.root.version, "4.0.9")
    verifyEq(s.root.purl, "pkg:generic/skyfoundry/haxall@4.0.9")
    verifyEq(s.fileName, "haxall-4.0.9.cdx.json")

    // components: pods, then xeto, then jars matched to pods
    verifyEq(s.comps.map |c->Str| { "$c.kind:$c.name" }, Str[
      "pod:codemirror", "pod:hx", "pod:slf4j_nop", "pod:sys",
      "xeto:hx.foo", "xeto:ph.points", "jar:sys.jar"])

    verifyComp(s, "pod:hx", "4.0.9", "AFL-3.0", "pkg:generic/fantom/hx@4.0.9")
    verifyComp(s, "pod:slf4j_nop", "1.7.25", "Apache-2.0", "pkg:generic/fantom/slf4j_nop@1.7.25")
    verifyComp(s, "pod:codemirror", "4.0.9", "LicenseRef-SkyFoundry-Commercial", "pkg:generic/fantom/codemirror@4.0.9")
    verifyComp(s, "xeto:ph.points", "5.0.0", "AFL-3.0", "pkg:generic/xeto/ph.points@5.0.0")
    verifyComp(s, "jar:sys.jar", "1.0.84", "AFL-3.0", "pkg:generic/fantom/sys.jar@1.0.84")
    verifyEq(comp(s, "xeto:ph.points").supplier, "Project Haystack")
    verifyEq(comp(s, "xeto:hx.foo").license, "LicenseRef-SkyFoundry-Commercial")

    // wrapped libs
    kids := comp(s, "pod:codemirror").children
    verifyEq(kids.map |k->Str| { "$k.name $k.version $k.supplier $k.license" },
      ["codemirror 5.48.0 codemirror MIT", "diff-match-patch abc google Apache-2.0"])
    verifyEq(s.purls.findAll { !it.startsWith("pkg:generic") },
      ["pkg:github/google/diff-match-patch@abc", "pkg:maven/org.slf4j/slf4j-api@1.7.25", "pkg:npm/codemirror@5.48.0"])

    // maven libs detected from pom.properties, else manifest; meta wins
    dirC := tempDir + `c/`
    writePod(dirC, "hx", "4.0.9", "Commercial", null, null)
    writePod(dirC, "pomPod", "1.0", "MIT", null, null, [
      "META-INF/maven/org.b/b-api/pom.properties": "groupId=org.b\nartifactId=b-api\nversion=2.0\n",
      "META-INF/maven/org.a/a-core/pom.properties": "groupId=org.a\nartifactId=a-core\nversion=1.1\n"])
    writePod(dirC, "mfPod", "3.0", "Apache 2.0", null, null, [
      "META-INF/MANIFEST.MF": "Manifest-Version: 1.0\nImplementation-Title: m-core\nImplementation-Version: 3.0\nImplementation-Vendor-Id: com.m\n"])
    writePod(dirC, "metaPod", "1.0", "MIT", null, "pkg:npm/x@1 MIT", [
      "META-INF/maven/org.z/z/pom.properties": "groupId=org.z\nartifactId=z\nversion=9\n"])
    s2 := Sbom([dirC])
    verifyEq(comp(s2, "pod:pomPod").children.map |k->Str| { "$k.purl $k.license $k.supplier" },
      ["pkg:maven/org.a/a-core@1.1 MIT org.a", "pkg:maven/org.b/b-api@2.0 MIT org.b"])
    verifyEq(comp(s2, "pod:mfPod").children.map |k->Str| { "$k.purl $k.license" },
      ["pkg:maven/com.m/m-core@3.0 Apache-2.0"])
    verifyEq(comp(s2, "pod:metaPod").children.map |k->Str| { k.purl }, ["pkg:npm/x@1"])
    verifyEq(comp(s2, "pod:hx").children.size, 0)

    // same lib embedded in two pods: two components, one purl
    writePod(dirC, "dupPod", "1.0", "MIT", null, "pkg:maven/org.a/a-core@1.1 MIT")
    s3 := Sbom([dirC])
    verifyEq(s3.purls.findAll { it == "pkg:maven/org.a/a-core@1.1" }.size, 1)
    verifyEq(s3.comps.findAll { it.children.any { it.purl == "pkg:maven/org.a/a-core@1.1" } }.size, 2)

    // json
    json := (Map)JsonInStream(Buf().with { s.writeJson(it.out) }.flip.in).readJson
    verifyEq(json["bomFormat"], "CycloneDX")
    verifyEq(json->get("metadata")->get("component")->get("name"), "Haxall")
    hx := ((List)json["components"]).find |Map c->Bool| { c["bom-ref"] == "pod:hx" } as Map
    verifyEq(hx["licenses"]->first->get("license")->get("id"), "AFL-3.0")
    verifyEq(hx["externalReferences"]->first->get("hashes")->first->get("alg"), "SHA-512")
    verifyEq(hx["externalReferences"]->first->get("hashes")->first->get("content")->size, 128)
    cm := ((List)json["components"]).find |Map c->Bool| { c["bom-ref"] == "pod:codemirror" } as Map
    verifyEq(cm["licenses"]->first->get("license")->get("name"), "LicenseRef-SkyFoundry-Commercial")
    deps := ((List)json["dependencies"]).find |Map d->Bool| { d["ref"] == "pod:hx" } as Map
    verifyEq(deps["dependsOn"], Obj?["pod:sys"])

    // deterministic
    verifyEq(toJsonStr(s), toJsonStr(Sbom([a, b])))
  }

  private Void verifyComp(Sbom s, Str ref, Str ver, Str lic, Str purl)
  {
    c := comp(s, ref)
    verifyEq(c.version, ver)
    verifyEq(c.license, lic)
    verifyEq(c.purl, purl)
  }

  private SbomComp comp(Sbom s, Str ref) { s.comps.find { it.ref == ref } }

  private Str toJsonStr(Sbom s) { Buf().with { s.writeJson(it.out) }.flip.readAllStr }

  private Void writePod(File dir, Str name, Str ver, Str lic, Str? depends, Str? purls, Str:Str files := [:])
  {
    props := ["pod.name": name, "pod.version": ver, "license.name": lic, "org.name": "Acme",
              "build.ts": "2026-11-07T10:00:00-05:00 New_York"]
    if (depends != null) props["pod.depends"] = depends
    if (purls != null) props["sbom.purl"] = purls
    writeZip(dir + `lib/fan/${name}.pod`, ["meta.props": props], files)
  }

  private Void writeXeto(File dir, Str name, Str ver, Str? depends, Str:Str build)
  {
    meta := ["name": name, "version": ver]
    if (depends != null) meta["depends"] = depends
    writeZip(dir + `lib/xeto/${name}.xetolib`, ["xeto-meta.props": meta, "xeto-build.props": build])
  }

  private Void writeZip(File file, Str:[Str:Str] entries, Str:Str files := [:])
  {
    zip := Zip.write(file.out)
    entries.each |props, name| { out := zip.writeNext(name.toUri); out.writeProps(props); out.close }
    files.each |text, name| { out := zip.writeNext(name.toUri); out.print(text); out.close }
    zip.close
  }

  private Void writeFile(File file, Str content) { file.out.print(content).close }
}
