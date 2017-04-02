using System;
using AVFoundation;
using CoreFoundation;
using CoreMedia;
using CoreVideo;
using Foundation;
using UIKit;
using System.Threading;
using System.Net;
using System.Text;
using Newtonsoft.Json.Linq;
using CoreGraphics;

namespace CtrlFSharp
{
	public partial class ViewController : UIViewController
	{
		protected ViewController(IntPtr handle) : base(handle)
		{
		}

		private Canvas canvas = new Canvas();
		private Timer timer;
		private AVCapturePhotoOutput photo;
		private PhotoCapture handler;

		public override void ViewDidLoad()
		{
			base.ViewDidLoad();
			handler = new PhotoCapture(canvas);
			canvas.BackgroundColor = UIColor.FromRGBA(0, 0, 0, 0);
			canvas.Frame = View.Bounds;
			canvas.Bounds = View.Bounds;
			View.AddSubview(canvas);

			var session = new AVCaptureSession();
			session.SessionPreset = AVCaptureSession.Preset1280x720;

			var cam = AVCaptureDevice.GetDefaultDevice(AVMediaTypes.Video);
			NSError err;
			cam.LockForConfiguration(out err);
			cam.ActiveVideoMinFrameDuration = new CMTime(1, 20);
			cam.UnlockForConfiguration();
			var camInput = AVCaptureDeviceInput.FromDevice(cam);
			session.AddInput(camInput);

			var layer = new AVCaptureVideoPreviewLayer(session);
			layer.VideoGravity = AVLayerVideoGravity.ResizeAspectFill;
			layer.Frame = View.Bounds;
			View.Layer.AddSublayer(layer);


			//stillImageOutput = new AVCaptureStillImageOutput();
			//session.AddOutput(stillImageOutput);
			photo = new AVCapturePhotoOutput();
			session.AddOutput(photo);

			session.StartRunning();

			var g = new UITapGestureRecognizer(() => View.EndEditing(true));
			g.CancelsTouchesInView = false; //for iOS5
			View.AddGestureRecognizer(g);

			View.BringSubviewToFront(canvas);
			View.BringSubviewToFront(txt);
		}

		private void TakePicture(object state)
		{
			var dict = new NSDictionary<NSString, NSObject>(AVVideo.CodecKey, AVVideo.CodecJPEG);
			var settings = AVCapturePhotoSettings.FromFormat(dict);
			photo.CapturePhoto(settings, handler);
		}

		partial void TextEntered(UITextField sender)
		{
			sender.ResignFirstResponder();

			if (string.IsNullOrWhiteSpace(sender.Text) || sender.Text.Length == 0)
			{
				timer?.Dispose();
				timer = null;
				canvas.Keyword = null;
			}
			else
			{
				canvas.Keyword = sender.Text.Trim().ToLowerInvariant();
				if (timer == null)
				{
					timer = new Timer(TakePicture, null, 1000, 1000);
				}
			}
		}
	}
}
