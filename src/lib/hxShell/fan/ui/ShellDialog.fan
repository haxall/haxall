//
// Copyright (c) 2021, SkyFoundry LLC
// Licensed under the Academic Free License version 3.0
//
// History:
//   4 Jun 2021  Brian Frank  Creation
//

using dom
using domkit
using haystack

**
** ShellDialog provides standardized dialog handling
**
@Js
internal class ShellDialog : Dialog
{

//////////////////////////////////////////////////////////////////////////
// Factories
//////////////////////////////////////////////////////////////////////////

  ** Convenience to open confirmation dialog
  static Void confirm(Str msg, Str extra, |->| onOk)
  {
    content := FlexBox
    {
      it.style->minWidth  = "350px"
      Label
      {
        it.text = "\u26A0"
        it.style->fontSize = "48px"
        it.style->padding = "0 16px 0 8px"
        it.style->color = "#f39c12"
      },
      Box
      {
        Box { Label { it.text = msg; it.style->fontWeight = "bold" }, },
        Box { Label { it.text = extra }, },
      },
    }

    ShellDialog
    {
      it.title   = "Confirm"
      it.buttons = [ok, cancel]
      it.content = content
      it.onOk |->Bool| { onOk(); return true }
    }.open
  }

  ** Convenience to open dialog to show monospaced text area
  static Void openText(Str title, Str text)
  {
    ShellDialog
    {
      it.title   = title
      it.buttons = [ok]
      it.content = makeTextArea(text)
    }.open
  }

  ** Convenience to open error dialog
  static Void openErrGrid(Grid g)
  {
    openErr(g.meta.dis, g.meta["errTrace"] as Str ?: "")
  }

  ** Convenience to open error dialog
  static Void openErr(Str dis, Str trace := "")
  {
    ShellDialog
    {
      it.title   = "Error"
      it.buttons = [ok]
      it.content = Box
      {
        it.style->minWidth  = "350px"
        it.add(ShellUtil.errElemSmall(dis))
        if (!trace.isEmpty) it.add(makeTextArea(trace))
      }
    }.open
  }

  ** Convenience to open a dialog to input Trio
  static Void promptTrio(Str title, Str trio, |Dict[]| onOk)
  {
    textArea := makeTextArea(trio)
    errBox := Box() { it.style->height = "32px" }
    Int? timeoutId
    ShellDialog
    {
      it.title   = title
      it.buttons = [ok, cancel]
      it.content = Box
      {
        textArea,
        errBox,
      }
      it.onOk |->Bool|
      {
        // clear previous timeout
        if (timeoutId != null)
        {
          Win.cur.clearTimeout(timeoutId)
          timeoutId = null
        }

        try
        {
          // parse content as trio and invoke ok callback
          onOk(TrioReader(textArea.val.in).readAllDicts)
          return true
        }
        catch (Err e)
        {
          // flash error message
          errBox.removeAll.add(ShellUtil.errElemSmall(e.toStr))
          timeoutId = Win.cur.setTimeout(5sec) { timeoutId = null; errBox.removeAll }
          return false
        }
      }
    }.open
  }

  ** Standard monospaced text area
  private static TextArea makeTextArea(Str text)
  {
    TextArea
    {
      it.val = text
      it.style->minWidth  = "600px"
      it.style->minHeight = "450px"
    }
  }

//////////////////////////////////////////////////////////////////////////
// Button Constants
//////////////////////////////////////////////////////////////////////////

  ** Command key for "OK" button
  static const Str ok := "OK"

  ** Command key for "Cancel" button
  static const Str cancel := "Cancel"

//////////////////////////////////////////////////////////////////////////
// Construction
//////////////////////////////////////////////////////////////////////////

  ** Construct dialog; must set title, command, buttons
  new make(|This| f) : super()
  {
    // call it-block initializer
    f(this)

    // sanity check it-block set all my fields
    if (title == null) throw Err("title not set")
    if (content == null) throw Err("content not set")
    if (buttons == null || buttons.isEmpty) throw Err("buttons not set")

    // key handling
    this.onKeyDown |e|
    {
      if (isDefaultAction(e)) fire(ok)
      if (e.key == Key.esc) fire(cancel)
    }

    // style the content element
    content.style->maxHeight = "${Win.cur.viewport.h - 100}px"
    content.style->maxWidth  = "${Win.cur.viewport.w - 100}px"
    content.style->overflow  = "auto"

    // build my action buttons
    buttonsBox := FlowBox
    {
      it.gaps = ["4px"]
      it.halign = Align.right
      it.style->padding = "8px"
    }
    buttons.each |b|
    {
      buttonsBox.add(Button {
        it.text = b
        it.style->minWidth = "60px"
        it.onAction { fire(b) }
      })
    }

    // put the whole thing together
    add(SashBox
    {
      it.dir = Dir.down
      it.sizes = ["auto", "auto"]
      Box { it.style->padding = "0 8px"; content, },
      buttonsBox,
    })
  }

//////////////////////////////////////////////////////////////////////////
// Instance Slots
//////////////////////////////////////////////////////////////////////////

  ** Dialog content; must set in it-block constructor
  Elem content

  ** Dialog command buttons; must set in it-block constructor
  Str[]? buttons

  ** Called when ok button fired; return true to close
  Void onOk(|This->Bool| f) { this.cbOk = f }
  private Func? cbOk := |->Bool| { true }

  ** Fire button with the given name
  private Void fire(Str name)
  {
    switch (name)
    {
      case ok:     if (cbOk(this)) close
      case cancel: close
    }
  }

  ** Return if given event should invoke a dialog's default button
  internal static Bool isDefaultAction(Event e)
  {
    // must be Enter key
    if (e.key != Key.enter) return false

    // if not a text area, then its a match
    if (!isTextArea(e.target)) return true

    // otherwise must a Cmd+Enter or Ctrl+Enter
    return e.ctrl || e.meta
  }

  ** Return if given focused element is a textarea
  internal static Bool isTextArea(Elem? elem)
  {
    elem?.tagName == "textarea"
  }
}