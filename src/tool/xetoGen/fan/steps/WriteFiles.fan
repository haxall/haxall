//
// Copyright (c) 2026, Brian Frank
// Licensed under the Academic Free License version 3.0
//
// History:
//   22 Jul 2026  Brian Frank  Creation
//

**
** Write generated lines back to changed files
**
internal class WriteFiles : Step
{
  override Void run()
  {
    numChanged := 0
    pods.each |pod|
    {
      pod.files.each |f|
      {
        if (!writeFile(f)) return
        numChanged++
      }
    }
    info("WriteFiles [$numChanged changed]")
  }

  ** Write file if generated lines changed; return if changed
  private Bool writeFile(AFile f)
  {
    newText := f.genLines.join("\n")
    if (newText == f.lines.join("\n")) return false
    if (compiler.preview)
    {
      info("preview [$f.file.osPath]")
    }
    else
    {
      f.file.out.print(newText).close
      info("write [$f.file.osPath]")
    }
    return true
  }
}

