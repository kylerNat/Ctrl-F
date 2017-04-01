//
//  ViewController.h
//  Ctrl-F
//
//  Created by Kyler Natividad on 4/1/17.
//
//

#import <UIKit/UIKit.h>

#import <opencv2/videoio/cap_ios.h>
using namespace cv;

@interface ViewController : UIViewController<CvVideoCameraDelegate>
{
    IBOutlet UIImageView* imageView;
    CvVideoCamera* videoCamera;
}

@property (nonatomic, retain) CvVideoCamera* videoCamera;

@end
