//
// Copyright (c) 2010, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   11 Nov 2010  Brian Frank  Creation
//

using xeto
using haystack
using axon
using hx

**
** IOTest
**
class IOTest : HxTest
{

  @HxTestProj
  Void testFileExt()
  {
    ext := proj.exts.file

    f := ext.resolve(`io/`)
    verifyEq(f.uri, `io/`)

    f = ext.resolve(`io/foo.txt`)
    verifyEq(f.uri, `io/foo.txt`)
    verifyEq(f.exists, false)
    f.out.print("hi").close

    f = ext.resolve(`io/foo.txt`)
    verifyEq(f.uri, `io/foo.txt`)
    verifyEq(f.exists, true)
    verifyEq(f.readAllStr, "hi")

    f = proj.dir + `io/foo.txt`
    echo(">>> $f.osPath")
    verifyEq(f.readAllStr, "hi")
  }

  @HxTestProj
  Void test()
  {
    addLib("hx.io")
    projDir := proj.dir

    // bad handles
    verifyErr(EvalErr#) { eval("ioReadStr(`test.txt`)") }
    verifyErr(EvalErr#) { eval("ioReadStr(`/test.txt`)") }
    verifyErr(EvalErr#) { eval("ioReadStr(`../test.txt`)") }
    verifyErr(EvalErr#) { eval("ioReadStr(`io/../../test.txt`)") }

    // ioRandom and ioToHex
    verifyEq(eval("""("bar").ioToHex"""), "626172")
    verifyEq(eval("""ioRandom(6).ioToHex.size"""), n(12))

    // basic strs
    eval("""ioWriteStr("hello world!", `io/test.txt`)""")
    verifyEq(eval("""ioReadStr(`io/test.txt`)"""), "hello world!")
    verifyEq(eval("""ioReadStr("str literal")"""), "str literal")

    // base str append
    eval("""ioWriteStr("a", `io/append.txt`.ioAppend)""")
    verifyEq(eval("""ioReadStr(`io/append.txt`)"""), "a")
    eval("""ioWriteStr("b", `io/append.txt`.ioAppend)""")
    verifyEq(eval("""ioReadStr(`io/append.txt`.ioAppend)"""), "ab")
    eval("""ioWriteStr("c\\nd", ioAppend(`io/append.txt`))""")
    verifyEq(eval("""ioReadStr(`io/append.txt`)"""), "abc\nd")
    eval("""ioWriteLines(["foo", "bar"], ioAppend(`io/append.txt`))""")
    verifyEq(eval("""ioReadStr(`io/append.txt`)"""), "abc\ndfoo\nbar\n")

    // lines
    eval("""ioWriteLines(["a123", "b123", "c123"], `io/lines.txt`)""")
    verifyEq(eval("""ioReadLines(`io/lines.txt`)"""), ["a123", "b123", "c123"])
    verifyEq(eval("""ioReadLines(`io/lines.txt`, {limit:3})"""), ["a12", "3", "b12", "3", "c12", "3"])
    verifyEq(eval("""(()=> do s: ""; ioEachLine(`io/lines.txt`) (x,i) => s = s + i + ":" +  x + " | "; s; end)()"""), "0:a123 | 1:b123 | 2:c123 | ")
    verifyEq(eval("""ioStreamLines(`io/lines.txt`).limit(2).collect"""), Obj?["a123", "b123"])
    verifyEq(eval("""ioStreamLines(`io/lines.txt`).limit(2).map(x=>x.upper).collect"""), Obj?["A123", "B123"])

    // trio format
    eval("""ioWriteTrio([{n:"Brian", age:30yr}, {n:"Andy", marker}], `io/test.trio`)""")
    Dict[] trio := eval("ioReadTrio(`io/test.trio`)")
    verifyEq(trio.size, 2)
    verifyDictEq(trio[0], ["n":"Brian", "age":n(30, "yr")])
    verifyDictEq(trio[1], ["n":"Andy", "marker":Marker.val])
    verifyEq(eval("""ioWriteTrio([{n:"Brian"}], "")"""), "n:Brian\n")
    verifyEq(eval("""ioWriteTrio([{n:"Brian"}], "// hi\\n")"""), "// hi\nn:Brian\n")
    verifyEq(eval("""{src:"source", c: "C", b:"B", a:"A"}.ioWriteTrio("")"""), "a:A\nb:B\nc:C\nsrc:source\n")
    verifyEq(eval("""{src:"source", c: "C", b:"B", a:"A"}.ioWriteTrio("", {noSort})"""), "src:source\nc:C\nb:B\na:A\n")

    // grid format
    eval("""ioWriteZinc([{n:"Brian", age:30yr}, {n:"Andy", marker}], `io/test.zinc`)""")
    Grid zinc := eval("ioReadZinc(`io/test.zinc`)")
    verifyEq(zinc.size, 2)
    verifyDictEq(zinc[0], ["n":"Brian", "age":n(30, "yr")])
    verifyDictEq(zinc[1], ["n":"Andy", "marker":Marker.val])

    // csv format
    eval("""ioWriteCsv([{n:"Brian", age:30yr}, {n:"Andy", marker}], `io/test.csv`)""")
    Grid csv := eval("ioReadCsv(`io/test.csv`)")
    verifyEq(csv.size, 2)
    verifyDictEq(csv[0], ["n":"Brian", "age":"30yr"])
    verifyDictEq(csv[1], ["n":"Andy", "marker":"\u2713"])

    // csv format with options
    eval("""ioWriteCsv([{n:"Brian", age:30yr}, {n:"Andy", marker}], `io/test-2.csv`, {delimiter:"|", newline:"\\r\\n"})""")
    Str s := (projDir + `io/test-2.csv`).readAllStr(false)
    verifyEq(s, "age|marker|n\r\n30yr|\"\"|Brian\r\n\"\"|\u2713|Andy\r\n")
    csv = eval("""ioReadCsv(`io/test-2.csv`, {delimiter:"|", noHeader})""")
    verifyEq(csv.size, 3)
    verifyEq(csv.colNames, ["v0", "v1", "v2"])

    // csv stream
    verifyDictsEq(eval("""ioStreamCsv(`io/test-2.csv`, {delimiter:"|"}).collect"""),
      [["n":"Brian", "age":"30yr"], ["n":"Andy", "marker":"\u2713"]])
    verifyDictsEq(eval("""ioStreamCsv(`io/test-2.csv`, {delimiter:"|", noHeader}).collect"""),
      [["v0":"age","v1":"marker","v2":"n"], ["v2":"Brian", "v0":"30yr"], ["v2":"Andy", "v1":"\u2713"]])

    // csv each
    verifyEq(eval("""(()=> do acc: []; ioEachCsv(`io/test.csv`, null) (x) => acc = acc.add(x[2]); acc; end)()"""), Obj?["n", "Brian", "Andy"])

    // csv format with no header
    eval("""ioWriteCsv([{n:"Brian", age:30yr}, {n:"Andy", marker}], `io/test-3.csv`, {delimiter:"|", newline:"\\r\\n", noHeader, stripUnits})""")
    s = (projDir + `io/test-3.csv`).readAllStr(false)
    verifyEq(s, "30|\"\"|Brian\r\n\"\"|\u2713|Andy\r\n")
    csv = eval("""ioReadCsv(`io/test-3.csv`, {delimiter:"|", noHeader})""")
    verifyEq(csv.size, 2)
    verifyEq(csv.colNames, ["v0", "v1", "v2"])

    // ioDir
    Grid dir := eval("""ioDir(`io/`).sort("name")""")
    verifyEq(dir.size, 8)
    verifyEq(dir[0]->name, "append.txt")
    verifyEq(dir[0]->size, n(13))
    verifyEq(dir[0]->mod->date, Date.today)

    // charsets
    verifyCharset("UTF-8")
    verifyCharset("UTF-16BE")
    verifyCharset("UTF-16LE")

    // copy
    projDir.plus(`io/foo.txt`).out.print("foo!").close
    eval("""ioCopy(`io/foo.txt`, `io/foo-copy.txt`)""")
    verifyEq(projDir.plus(`io/foo-copy.txt`).exists, true)
    verifyEq(projDir.plus(`io/foo-copy.txt`).readAllStr, "foo!")
    projDir.plus(`io/foo.txt`).out.print("foo 2!").close
    verifyErr(EvalErr#) { eval("""ioCopy(`io/foo.txt`, `io/foo-copy.txt`)""") }
    verifyEq(projDir.plus(`io/foo-copy.txt`).readAllStr, "foo!")
    eval("""ioCopy(`io/foo.txt`, `io/foo-copy.txt`, {overwrite: false})""")
    verifyEq(projDir.plus(`io/foo-copy.txt`).readAllStr, "foo!")
    eval("""ioCopy(`io/foo.txt`, `io/foo-copy.txt`, {overwrite})""")
    verifyEq(projDir.plus(`io/foo-copy.txt`).readAllStr, "foo 2!")

    // copy dir
    projDir.plus(`io/sub/a.txt`).out.print("a!").close
    projDir.plus(`io/sub/b.txt`).out.print("b!").close
    eval("""ioCopy(`io/sub/`, `io/sub-copy/`)""")
    verifyEq(projDir.plus(`io/sub-copy/a.txt`).readAllStr, "a!")
    verifyEq(projDir.plus(`io/sub-copy/b.txt`).readAllStr, "b!")

    // move
    eval("""ioMove(`io/sub-copy/b.txt`, `io/sub-copy/b2.txt`)""")
    eval("""ioMove(`io/sub-copy/`, `io/sub-move/`)""")
    verifyEq(projDir.plus(`io/sub-copy/`).exists, false)
    verifyEq(projDir.plus(`io/sub-move/`).exists, true)
    verifyEq(projDir.plus(`io/sub-move/a.txt`).readAllStr, "a!")
    verifyEq(projDir.plus(`io/sub-move/b2.txt`).readAllStr, "b!")

    // delete
    verifyEq(projDir.plus(`io/lines.txt`).exists, true)
    eval("""ioDelete(`io/lines.txt`)""")
    verifyEq(projDir.plus(`io/lines.txt`).exists, false)

    // create
    verifyEq(projDir.plus(`io/foo/`).exists, false)
    eval("""ioCreate(`io/foo/`)""")
    verifyEq(projDir.plus(`io/foo/`).exists, true)
    verifyEq(projDir.plus(`io/foo/bar.txt`).exists, false)
    eval("""ioCreate(`io/foo/bar.txt`)""")
    verifyEq(projDir.plus(`io/foo/bar.txt`).exists, true)
    verifyEq(projDir.plus(`io/foo/bar.txt`).readAllStr, "")

    // torture csv
    projDir.plus(`io/more.csv`).out.print(
      """Name,Name, name , , Foo Bar,
         B,Brian,Frank,b1,3,b2
         A,Andy,Frank,b1,4,""").close

    csv = eval("""ioReadCsv(`io/more.csv`)""")
    verifyDictEq(csv[0], ["name":"B", "name_1":"Brian", "name_2":"Frank", "fooBar":"3", "blank":"b1", "blank_1":"b2"])
    verifyDictEq(csv[1], ["name":"A", "name_1":"Andy", "name_2":"Frank", "fooBar":"4", "blank":"b1", "blank_1":null])

    // ioWriteXml
    eval("""ioWriteXml([{n:"Brian", age:30yr}, {n:"Andy", foo}], `io/test.xml`)""")
    verifyEq(projDir.plus(`io/test.xml`).readAllStr,
      """<grid ver='3.0'>

         <cols>
         <age/>
         <foo/>
         <n/>
         </cols>

         <row>
         <age kind='Number' val='30yr'/>
         <n kind='Str' val='Brian'/>
         </row>
         <row>
         <foo kind='Marker'/>
         <n kind='Str' val='Andy'/>
         </row>
         </grid>
         """)

    // ioWriteXml with nested collections
    eval("""{l:[1,2], d:{dis:"Dict"}, g:[].toGrid}.toGrid({foo, bar:^hi}).addColMeta("d", {dis:"D&D", x:{baz}}).ioWriteXml(`io/test.xml`)""")
    verifyEq(projDir.plus(`io/test.xml`).readAllStr,
      """<grid ver='3.0'>
         <meta>
         <foo kind='Marker'/>
         <bar kind='Symbol' val='hi'/>
         </meta>

         <cols>
         <l/>
         <d dis='D&amp;D'>
         <meta>
         <x kind='Dict'>
         <baz kind='Marker'/>
         </x>
         </meta>
         </d>
         <g/>
         </cols>

         <row>
         <l kind='List'>
         <item kind='Number' val='1'/>
         <item kind='Number' val='2'/>
         </l>
         <d kind='Dict'>
         <dis kind='Str' val='Dict'/>
         </d>
         <g kind='Grid'>

         <cols>
         <empty/>
         </cols>

         </g>
         </row>
         </grid>
         """)

    // ioReadJson
    projDir.plus(`io/json.txt`).out.print(
      Str<|{"name":"Brian",
           "int": 123,
           "float": 10.2,
           "bool": true,
           "list": [1, null, 3],
           "map.it": {"foo":9},
           "whatType":"d:2018-07-18"
           }|>).close
    Dict json :=  eval("""ioReadJson(`io/json.txt`, {v3})""")
    verifyEq(json->name, "Brian")
    verifyEq(json->int, n(123))
    verifyEq(json->float, n(10.2f))
    verifyEq(json->bool, true)
    verifyEq(json->list, [n(1), null, n(3)])
    verify(json["map.it"] is Dict)
    verifyEq(json["map.it"]->foo, n(9))
    verifyEq(json->whatType, Date("2018-07-18"))

    // ioReadJson {safeNames} (Hayson)
    json =  eval("""ioReadJson(`io/json.txt`, {safeNames})""")
    verify(json->map_it is Dict)
    verifyEq(json->map_it->foo, n(9))
    verifyEq(json->whatType, "d:2018-07-18")

    // ioReadJson {v3, safeNames, notHaystack}
    json =  eval("""ioReadJson(`io/json.txt`, {v3, safeNames, notHaystack})""")
    verify(json->map_it is Dict)
    verifyEq(json->map_it->foo, n(9))
    verifyEq(json->whatType, "d:2018-07-18")

    // ioReadJson {safeVals}
    projDir.plus(`io/json.txt`).out.print(
      Str<|{"a":"d:2018-07-18",
            "b":"d:bad"}|>).close
    json =  eval("""ioReadJson(`io/json.txt`, {v3, safeVals})""")
    verifyEq(json->a, Date("2018-07-18"))
    verifyEq(json->b, "d:bad")

    // ioWriteJson (v3)
    eval("""ioWriteJson([{n:"Brian", age:30yr}, {n:"Andy", bday:1980-01-31, nil: null}], `io/json.txt`, {v3})""")
    verifyEq(projDir.plus(`io/json.txt`).readAllStr,
      """[{"n":"Brian", "age":"n:30 yr"}, {"n":"Andy", "bday":"d:1980-01-31"}]""") // nil:null stripped
    verifyEq(eval(Str<|ioWriteJson("75°F", "")|>), Str<|"75\u00b0F"|>)
    verifyEq(eval(Str<|ioWriteJson("75°F", "", {noEscapeUnicode})|>), Str<|"75°F"|>)

    eval("""ioWriteJson([{n:"Brian", age:30yr}, {n:"Andy"}].toGrid.reorderCols(["n", "age"]), `io/json.txt`, {v3})""")
    verifyEq(projDir.plus(`io/json.txt`).readAllStr,
      """{
         "meta": {"ver":"3.0"},
         "cols":[
         {"name":"n"},
         {"name":"age"}
         ],
         "rows":[
         {"n":"Brian", "age":"n:30 yr"},
         {"n":"Andy"}
         ]
         }
         """)

    // ioReadJsonGrid
    Grid g := eval("ioReadJsonGrid(`io/json.txt`, {v3})")
    verifyGridEq(g, eval("""[{n:"Brian", age:30yr}, {n:"Andy"}].toGrid.reorderCols(["n", "age"])"""))

    // ioReadXeto
    projDir.plus(`io/foo.xeto`).out.print(
      Str<|Date "2023-11-21"|>).close
    xeto :=  eval("""ioReadXeto(`io/foo.xeto`)""")
    verifyEq(xeto, Date("2023-11-21"))
    projDir.plus(`io/foo.xeto`).out.print(
      Str<|sys::Dict {
             ref: @foo-bar
           }|>).close
    xeto =  eval("""ioReadXeto(`io/foo.xeto`, {externRefs})""")
    verifyDictEq(xeto, ["ref":Ref("foo-bar")])

    // ioWriteXeto
    eval("""ioWriteXeto([{n:"Brian", age:30yr}, {n:"Andy", bday:1980-01-31}], `io/foo.xeto`)""")
    verifyEq(projDir.plus(`io/foo.xeto`).readAllStr.trim,
      """Dict {
           n: "Brian"
           age: Number "30yr"
         }

         Dict {
           n: "Andy"
           bday: Date "1980-01-31"
         }""")

    // ioZipDir
    zip := Zip.write(projDir.plus(`io/zipped.zip`).out)
    zip.writeNext(`/alpha.txt`).print("alpha!").close
    zip.writeNext(`/beta.csv`).print("a,b\n1a,1b\n2a,2b").close
    zip.close
    dir = eval("""ioZipDir(`io/zipped.zip`)""")
    verifyEq(dir.size, 2)
    verifyEq(dir[0]->path, `/alpha.txt`)
    verifyEq(dir[0]->size, n(6))
    verifyEq(dir[0]->mod->date, Date.today)
    verifyEq(dir[1]->path, `/beta.csv`)
    verifyEq(eval("""ioZipEntry(`io/zipped.zip`, `/alpha.txt`).ioReadStr"""), "alpha!")
    csv = eval("""ioZipEntry(`io/zipped.zip`, `/beta.csv`).ioReadCsv""")
    verifyDictEq(csv[0], ["a":"1a", "b":"1b"])
    verifyDictEq(csv[1], ["a":"2a", "b":"2b"])

    // ioGzip
    Zip.gzipOutStream(projDir.plus(`io/foo.gz`).out).print("a,b\n1,2\n3,4\n").close
    verifyEq(eval("""ioGzip(`io/foo.gz`).ioReadStr"""), "a,b\n1,2\n3,4\n")
    verifyDictEq(eval("""ioGzip(`io/foo.gz`).ioReadCsv.first"""), ["a":"1", "b":"2"])
    eval("""\"gzip out!\".ioWriteStr(ioGzip(`io/bar.gz`))""")
    verifyEq(Zip.gzipInStream(projDir.plus(`io/bar.gz`).in).readAllStr, "gzip out!")

    // ioToBase64 / ioFromBase64
    verifyEq(eval("""ioToBase64("safe base64~~")"""),        "safe base64~~".toBuf.toBase64)
    verifyEq(eval("""ioToBase64("safe base64~~", null)"""),  "safe base64~~".toBuf.toBase64)
    verifyEq(eval("""ioToBase64("safe base64~~", {uri})"""), "safe base64~~".toBuf.toBase64Uri)
    verifyEq(eval("""ioFromBase64("c2t5c3Bhcms").ioReadStr"""), "skyspark")

    // ioCrc
    verifyEq(eval("""ioCrc("foo", "CRC-32").toHex"""),  "foo".toBuf.crc("CRC-32").toHex)

    // ioDigest
    verifyEq(eval("""ioDigest("foo", "MD5").ioToBase64"""),  "foo".toBuf.toDigest("MD5").toBase64)
    verifyEq(eval("""ioDigest("foo", "SHA-1").ioToBase64"""),  "foo".toBuf.toDigest("SHA-1").toBase64)

    // ioHmac
    verifyEq(eval("""ioHmac("foo", "SHA-1", "secret").ioToBase64"""),  "foo".toBuf.hmac("SHA-1", "secret".toBuf).toBase64)

    // ioPbk
    verifyEq(eval("""ioPbk("PBKDF2WithHmacSHA1", "secret", "_salt_", 1000, 20).ioToBase64"""),
      Buf.pbk("PBKDF2WithHmacSHA1", "secret", "_salt_".toBuf, 1000, 20).toBase64)

    // ioSkip lines
    verifyEq(eval(Str<|ioSkip("a\n\nc\nd\ne", {lines:0}).ioReadLines|>), ["a", "", "c", "d", "e"])
    verifyEq(eval(Str<|ioSkip("a\n\nc\nd\ne", {lines:1}).ioReadLines|>), ["", "c", "d", "e"])
    verifyEq(eval(Str<|ioSkip("a\n\nc\nd\ne", {lines:2}).ioReadLines|>), ["c", "d", "e"])
    verifyEq(eval(Str<|ioSkip("a\n\nc\nd\ne", {lines:3}).ioReadLines|>), ["d", "e"])
    verifyEq(eval(Str<|ioSkip("a\n\nc\nd\ne", {lines:4}).ioReadLines|>), ["e"])
    verifyEq(eval(Str<|ioSkip("a\n\nc\nd\ne", {lines:5}).ioReadLines|>), Str[,])
    verifyEq(eval(Str<|ioSkip("a\n\nc\nd\ne", {lines:6}).ioReadLines|>), Str[,])

    // ioSkip chars
    verifyEq(eval(Str<|ioSkip("a\u0394bcde", {chars:0}).ioReadStr|>), "a\u0394bcde")
    verifyEq(eval(Str<|ioSkip("a\u0394bcde", {chars:1}).ioReadStr|>), "\u0394bcde")
    verifyEq(eval(Str<|ioSkip("a\u0394bcde", {chars:2}).ioReadStr|>), "bcde")
    verifyEq(eval(Str<|ioSkip("a\u0394bcde", {chars:5}).ioReadStr|>), "e")
    verifyEq(eval(Str<|ioSkip("a\u0394bcde", {chars:6}).ioReadStr|>), "")

    // ioSkip bom (and bytes)
    verifySkipBom([0xFE, 0xFF],       Charset.utf16BE)
    verifySkipBom([0xFF, 0xFE],       Charset.utf16LE)
    verifySkipBom([0xEF, 0xBB, 0xBF], Charset.utf8)

    // fan:// handles
    str := eval("ioReadStr(`fan://haystack/locale/en.props`)").toStr
    verifyEq(str.contains("Copyright"), true)
    verifyErr(EvalErr#) { eval("ioReadStr(`fan://ioExt/lib/lib.trio`)") }
    verifyErr(EvalErr#) { eval("ioReadStr(`fan://ioExt/badfile.txt`)") }
    verifyErr(EvalErr#) { eval("ioReadStr(`fan://badPodFooBar/badfile.txt`)") }

    // folio file
    rec := addRec(["file":m, "folio":m, "spec":Ref("sys::File")])
    eval("""ioWriteStr("folio file test!", readById(${rec.id.toCode}))""")
    text := eval("""readById(${rec.id.toCode}).ioReadStr()""")
    verifyEq(text, "folio file test!")

    // bins (SkySpark only)
    if (sys.info.rt.isSkySpark)
    {
      f := addRec(["file": Bin("text/plain")])
      eval("""ioWriteStr("bin test!", readById($f.id.toCode))""")
      text = eval("""readById($f.id.toCode).ioReadStr()""")
      verifyEq(text, "bin test!")

      // bin (foo)
      f = addRec(["foo": Bin("text/plain")])
      eval("""ioWriteStr("bin test foo!", readById($f.id.toCode).ioBin("foo"))""")
      text = eval("""ioBin(readById($f.id.toCode), "foo").ioReadStr()""")
      verifyEq(text, "bin test foo!")
    }
  }

  Void verifyEvalErrMsg(Str axon, Str msg)
  {
    try
    {
      eval(axon)
      fail
    }
    catch (EvalErr e)
    {
      // echo("::: $e")
      verifyEq(e.cause.toStr, msg)
    }
  }

  Void verifyCharset(Str charset)
  {
    // write
    unicode := "abc \u00ab ! \u01cf \n \u3c00"
    expr := """ioWriteStr($unicode.toCode, `io/charset.txt`.ioCharset($charset.toCode))"""
    eval(expr)

    // read with Fantom
    in := proj.dir.plus(`io/charset.txt`).in
    in.charset = Charset(charset)
    verifyEq(in.readAllStr, unicode)
    in.close

    // read with IO
    verifyEq(eval("ioReadStr(ioCharset(`io/charset.txt`, $charset.toCode))"), unicode)
  }

  @HxTestProj
  Void testBufHandle()
  {
    buf := Buf()
    h := IOHandle.fromObj(proj, buf)
    verify(h is BufHandle)
    res := h.withOut |out| { out.writeChars("Foo") }
    verifyEq(res->size, n(3))
    h = IOHandle.fromObj(proj, buf.flip)
    s := h.withIn |in| { in.readAllStr }
    verifyEq(s, "Foo")
  }

  Void verifySkipBom(Int[] bytes, Charset charset)
  {
    str := "skyspark \u0394 rocks!\nline 2"
    buf := Buf()
    bytes.each |b| { buf.write(b) }
    buf.charset = charset
    buf.print(str)
    base64 := buf.toBase64

    // with BOM
    verifyEq(eval("ioFromBase64($base64.toCode).ioSkip({bom}).ioReadStr"), str)
    verifyEq(eval("ioFromBase64($base64.toCode).ioSkip({bom, chars:2}).ioReadStr"), str[2..-1])
    verifyEq(eval("ioFromBase64($base64.toCode).ioSkip({bom, lines:1}).ioReadStr"), "line 2")

    // bytes
    verifyEq(eval("ioFromBase64($base64.toCode).ioSkip({bytes:$bytes.size}).ioCharset($charset.toStr.toCode).ioReadStr"), str)

    // no BOM
    base64 = Buf().print(str).toBase64
    verifyEq(eval("ioFromBase64($base64.toCode).ioSkip({bom}).ioReadStr"), str)

  }

}

