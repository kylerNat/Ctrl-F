
#import <Foundation/Foundation.h>


@interface Vision : NSObject {
	
}

+ (void) ProcessImage: (uint32_t*) bitmapData
                width: (int) w
               height: (int) h
           searchText: (char*) string;

@end
