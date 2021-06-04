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
  ** Command key for "OK" button
  static const Str ok := "OK"

  ** Command key for "Cancel" button
  static const Str cancel := "Cancel"

  ** Convenience to open dialog to show monospaced text area
  static Void openText(Str title, Str text)
  {
    ShellDialog
    {
      it.title   = title
      it.buttons = [ok]
      it.content = TextArea
      {
        it.val = text
        it.style->minWidth  = "500px"
        it.style->minHeight = "300px"
      }
    }.open
  }

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
      switch (e.key)
      {
        case Key.esc:   fire(cancel)
        case Key.enter: fire(ok)
      }
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
}