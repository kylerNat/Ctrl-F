// WARNING
//
// This file has been generated automatically by Xamarin Studio from the outlets and
// actions declared in your storyboard file.
// Manual changes to this file will not be maintained.
//
using Foundation;
using System;
using System.CodeDom.Compiler;

namespace CtrlFSharp
{
    [Register ("ViewController")]
    partial class ViewController
    {
        [Outlet]
        [GeneratedCode ("iOS Designer", "1.0")]
        UIKit.UITextField txt { get; set; }

        [Action ("TextEntered:")]
        [GeneratedCode ("iOS Designer", "1.0")]
        partial void TextEntered (UIKit.UITextField sender);

        void ReleaseDesignerOutlets ()
        {
            if (txt != null) {
                txt.Dispose ();
                txt = null;
            }
        }
    }
}