/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	Application preview view.
*/

@import AVFoundation;

#import "AVCamPreviewView.h"

@implementation AVCamPreviewView

+ (Class)layerClass
{
	return [AVCaptureVideoPreviewLayer class];
}

- (AVCaptureVideoPreviewLayer *)videoPreviewLayer
{
	return (AVCaptureVideoPreviewLayer *)self.layer;
}

- (AVCaptureSession *)session
{
	return self.videoPreviewLayer.session;
}

- (void)setSession:(AVCaptureSession *)session
{
	self.videoPreviewLayer.session = session;
}

// - (void)drawRect:(CGRect)rect
// {
//     CGContextRef context = UIGraphicsGetCurrentContext();
        
//     CGContextSetRGBFillColor(context, 1, 0, 0, 1);
//     CGContextAddEllipseInRect(context, rect);
//     // [self CGContextBeginPath:c];
//     // [c CGContextMoveToPoint:[rect CGRectGetMinX] y:[rect CGRectGetMinY]];
//     // [c CGContextAddLineToPoint:[rect CGRectGetMinX] y:[rect CGRectGetMaxY]];
//     // [c CGContextAddLineToPoint:[rect CGRectGetMaxY] y:[rect CGRectGetMinY]];

// }

@end
