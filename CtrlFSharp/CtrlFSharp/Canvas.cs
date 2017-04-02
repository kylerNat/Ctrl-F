using System;
using UIKit;
using CoreGraphics;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using System.Collections.Generic;

namespace CtrlFSharp
{
	public class Canvas : UIView
	{
		public JObject Boxes { get; set; }
		public string Keyword { get; set; }

		public override void Draw(CGRect rect)
		{
			base.Draw(rect);
			if (Boxes == null) return;

			using (var g = UIGraphics.GetCurrentContext())
			{
				g.SetLineWidth(3);
				g.SetStrokeColor(UIColor.Red.CGColor);
				g.ClearRect(UIScreen.MainScreen.Bounds);
				Transform = CGAffineTransform.MakeIdentity();

				var regions = Boxes["regions"] as JArray;
				var ori = Boxes["orientation"].ToString();
				foreach (var reg in regions)
				{
					var lines = reg["lines"] as JArray;
					foreach (var line in lines)
					{
						var words = line["words"];
						foreach (var word in words)
						{
							if (word["text"].ToString() == Keyword)
							{
								nfloat x = 0, y = 0, w = 0, h = 0;
								var points = word["boundingBox"].ToString().Split(',');

								x = int.Parse(points[0]) / 720.0f * Bounds.Width;
								y = int.Parse(points[1]) / 1280.0f * Bounds.Height;
								w = int.Parse(points[2]) * 0.8f;// / 1280f * Bounds.Height;
								h = int.Parse(points[3]) * 0.8f;// / 720f * Bounds.Width;

								g.MoveTo(x, y);
								g.AddLineToPoint(x + w, y);
								g.AddLineToPoint(x + w, y + h);
								g.AddLineToPoint(x, y + h);
								g.AddLineToPoint(x, y);
							}
						}
					}
				}

				g.DrawPath(CGPathDrawingMode.Stroke);
				var angle = Boxes["textAngle"];
				if (angle != null)
				{
					var degree = double.Parse(angle.ToString());

					if (ori == "Left")
					{
						degree -= 90;
					}
					else if (ori == "Right")
					{
						degree += 90;
					}
					else if (ori == "Down")
					{
						degree += 180;
					}
					degree = degree / 180 * Math.PI;
					Transform = CGAffineTransform.MakeRotation(new nfloat(degree));
				}
			}
		}
	}
}
