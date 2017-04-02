using System;
using CoreMedia;
using AVFoundation;
using Foundation;
using CoreGraphics;
using System.Net;
using Newtonsoft.Json.Linq;
using System.Text;

namespace CtrlFSharp
{
	public class PhotoCapture : AVCapturePhotoCaptureDelegate
	{
		public PhotoCapture(Canvas can)
		{
			canvas = can;
		}

		private Canvas canvas;

		public override void DidFinishProcessingPhoto(AVCapturePhotoOutput captureOutput,
													  CMSampleBuffer photoSampleBuffer,
													  CMSampleBuffer previewPhotoSampleBuffer,
													  AVCaptureResolvedPhotoSettings resolvedSettings,
													  AVCaptureBracketedStillImageSettings bracketSettings,
													  NSError error)
		{
			Console.WriteLine(resolvedSettings.PhotoDimensions);
			var data = AVCapturePhotoOutput.GetJpegPhotoDataRepresentation(photoSampleBuffer, previewPhotoSampleBuffer).ToArray();
			using (var client = new WebClient())
			{
				client.Headers.Add("Content-Type", "application/octet-stream");
				client.Headers.Add("Ocp-Apim-Subscription-Key", "204f1b2bad4749d78c84d2bb66691422");
				try
				{
					var res = Encoding.UTF8.GetString(client.UploadData("https://westus.api.cognitive.microsoft.com/vision/v1.0/ocr?language=en", data));
					canvas.Boxes = JObject.Parse(res);
					canvas.BeginInvokeOnMainThread(() =>
					{
						canvas.SetNeedsDisplay();
					});

					Console.WriteLine(res);
				}
				catch (WebException ex)
				{
					var stream = ex.Response.GetResponseStream();
					var buffer = new byte[stream.Length];
					stream.Read(buffer, 0, buffer.Length);
					Console.WriteLine(Encoding.UTF8.GetString(buffer));
				}
				finally
				{
					client.Dispose();
				}
			}
			photoSampleBuffer.Dispose();
		}
	}
}