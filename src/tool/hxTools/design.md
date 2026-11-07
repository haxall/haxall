# hxTools Design

## SBOM

`SbomCli.fan` generates a CycloneDX 1.6 software bill of materials for
the EU Cyber Resilience Act, with the fields required by BSI TR-03183-2.

- `SbomCli`: the `hx sbom` command (`-o`, `-dir`, `-purls`)
- `Sbom`: scans an install and writes JSON, a purl list, or a Grid
- `SbomComp`: one component; built by the `makePod`, `makeXeto`,
  `makeJar`, `makeRoot`, and `makeWrapped` factories

SkySpark exposes the same generator through `installSbom()` in
`hxInstall`, shown by the SBOM button in Host | Install.

### Scan

`Sbom` walks `lib/fan`, `lib/xeto`, and `lib/java` of each `Env.cur.path`
directory, first match by file name winning like pod resolution; `-dir`
scans a single unzipped install instead.  Everything comes from files
already in the install: `meta.props`, `xeto-meta.props`,
`xeto-build.props`, and the file bytes for the SHA-512 hash.  A jar is
included only when a pod of the same name exists (`sys.jar` for
`sys.pod`) and takes its metadata from that pod.  `bin/` and `etc/` are
excluded since they cannot carry a CVE.

The root component is SkySpark if `skyarcd` is installed, else Haxall.

### Identity

Every component has a Package URL.  Fantom and Xeto have no registered
purl type, so pods and libs use `pkg:generic/fantom/<pod>@<ver>` and
`pkg:generic/xeto/<lib>@<ver>`.

Third party libs packaged unmodified inside a pod become child components
with their upstream purls, so scanners match upstream CVEs:

- `sbom.purl` pod meta: comma separated `<purl> [<SPDX license>]`
  entries; always wins when present
- otherwise Maven libs unpacked into the pod are detected from
  `META-INF/maven/*/*/pom.properties`, falling back to the jar manifest
  `Implementation-*` fields; detected libs take the pod's license

Children never replace the pod's own purl, since a pod like `hxUser` is
our code that merely includes a vendored file.  Code ported into Fantom
is not a child; upstream CVEs do not apply to it.

### Licenses

Free text `license.name` values map to SPDX ids.  Pods and libs that
declare no license default to `LicenseRef-SkyFoundry-Commercial`, which
CycloneDX requires in `license.name` rather than `license.id`.  Child libs
never get a default.

### Determinism

Output must be byte-identical for the same install so an archived release
reproduces its SBOM by running its own `hx sbom`:

- ordered maps for JSON keys; components sorted by kind then name
- no `serialNumber`; `metadata.timestamp` is the root pod's `build.ts`
- JSON file paths are relative to the scan root (`lib/fan/sys.pod`);
  only the Grid shows OS paths
