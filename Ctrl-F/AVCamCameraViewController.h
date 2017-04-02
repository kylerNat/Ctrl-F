/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	View controller for camera interface.
*/

@import UIKit;
#import <TesseractOCR/TesseractOCR.h>


@interface AVCamCameraViewController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate, UISearchBarDelegate, UISearchDisplayDelegate, G8TesseractDelegate>

@end
