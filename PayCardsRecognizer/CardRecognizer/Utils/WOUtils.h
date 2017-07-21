//
//  WOUtils.h
//  CardRecognizer
//
//  Created by Vladimir Tchernitski on 23/06/15.
//  Copyright (c) 2015 Vladimir Tchernitski. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>

#ifdef __cplusplus
#import <opencv2/opencv.hpp>
#endif

using namespace cv;

@interface WOUtils : NSObject

+ (UIImage *)imageFromMat:(Mat)cvMat;

@end
