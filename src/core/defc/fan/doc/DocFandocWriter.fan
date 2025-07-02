//
// Copyright (c) 2023, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 May 2023  Brian Frank  Creation
//

using fandoc
using xeto
using haystack

**
** DocFandocWriter
**
internal class DocFandocWriter : HtmlDocWriter
{

  new make(OutStream out) : super(out) {}

  override Void elemStart(DocElem elem)
  {
    if (elem.id === DocNodeId.pre)
    {
      text := elem.toText
      if (text.startsWith("ver:\""))
      {
        try
        {
          if (writePreZinc(text)) return
        }
        catch (Err e)
        {
          echo
          echo("ERROR: cannot parse zinc")
          echo("  $e")
          echo(text)
        }
      }
    }

    super.elemStart(elem)
  }

  Bool writePreZinc(Str zinc)
  {
    if (!zinc.endsWith("\n")) zinc = zinc + "\n"

    grid := ZincReader(zinc.in).readGrid

    json := JsonWriter.valToStr(grid)
             .splitLines
             .map(|x| { x.startsWith("{") && x.size > 2 ? "  $x" : x })
             .join("\n")

    id := Ref.gen
    idZinc := "$id-zinc"
    idJson:= "$id-json"

    out.printLine("<div class='defc-preToggle' id='$idZinc'>")
    out.printLine("  <div class='defc-preToggle-bar'>")
    out.printLine("  <span class='defc-preToggle-sel'>Zinc</span>")
    out.printLine("  <span onclick='" +  clickJs(idJson, idZinc) + "'>JSON</span>")
    out.printLine("  </div>")
    out.printLine("  <pre>")
    safeText(zinc)
    out.printLine("  </pre>")
    out.printLine("</div>")

    out.printLine("<div class='defc-preToggle' id='$idJson' style='display:none;'>")
    out.printLine("  <div class='defc-preToggle-bar'>")
    out.printLine("  <span onclick='" +  clickJs(idZinc, idJson) + "'>Zinc</span>")
    out.printLine("  <span class='defc-preToggle-sel'>JSON</span>")
    out.printLine("  </div>")
    out.printLine("  <pre>")
    safeText(json)
    out.printLine("  </pre>")
    out.printLine("</div>")

    inPreZinc = true
    return true
  }

  override Void text(DocText text)
  {
    if (!inPreZinc) super.text(text)
  }

  override Void elemEnd(DocElem elem)
  {
    if (!inPreZinc) super.elemEnd(elem)
    inPreZinc = false
  }

  private Str clickJs(Str show, Str hide)
  {
    """document.getElementById($show.toCode).style.display="block"; """ +
    """document.getElementById($hide.toCode).style.display="none";"""
  }

  private Bool inPreZinc

}

