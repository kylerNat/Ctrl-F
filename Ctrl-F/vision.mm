#import "vision.h"

@implementation Vision

#ifdef __cplusplus
#import <opencv2/opencv.hpp>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/highgui.hpp>
#include <opencv2/imgproc.hpp>
#include <string.h>

using namespace cv;

// + (void) deskew((uint32_t*) img)
// {
//     m = moments(img, 1);
//     if(abs(m['mu02']) < 1e-2)
//     {
//         return img.copy();
//     }
//     skew = m['mu11']/m['mu02']
//     M = np.float32([[1, skew, -0.5*SZ*skew], [0, 1, 0]])
//     img = cv2.warpAffine(img,M,(SZ, SZ),flags=affine_flags)
//             return img;
// }

// def hog(img):
//     gx = cv2.Sobel(img, cv2.CV_32F, 1, 0)
//     gy = cv2.Sobel(img, cv2.CV_32F, 0, 1)
//     mag, ang = cv2.cartToPolar(gx, gy)
//     bins = np.int32(bin_n*ang/(2*np.pi))    # quantizing binvalues in (0...16)
//     bin_cells = bins[:10,:10], bins[10:,:10], bins[:10,10:], bins[10:,10:]
//     mag_cells = mag[:10,:10], mag[10:,:10], mag[:10,10:], mag[10:,10:]
//     hists = [np.bincount(b.ravel(), m.ravel(), bin_n) for b, m in zip(bin_cells, mag_cells)]
//     hist = np.hstack(hists)     # hist is a 64 bit vector
//     return hist

+ (void) ProcessImage: (uint32_t*) bitmapData
                width: (int) w
               height: (int) h
           searchText: (char*) string
{
    {//Find candidate letters
        Mat img(h,w,CV_32SC1);
        Mat og = Mat(h, w, CV_8UC4, (unsigned char*) bitmapData);
        og.data = (unsigned char*) bitmapData;
        
        cvtColor(og, img, CV_BGR2GRAY);
        blur(img, img, cv::Size(3,3));
        // memcpy(bitmapData, img.data, w*h);
        
        for (int i=0; i<img.rows; ++i)
            for (int j=0; j<img.rows; ++j)
                bitmapData[j+i*w] = img[i][j];

        //TODO: free
    }
}

#endif
@end
