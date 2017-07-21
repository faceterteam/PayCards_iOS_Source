//
//  PayCardsRecognizer.m
//  CardRecognizer
//
//  Created by Vladimir Tchernitski on 04/12/15.
//  Copyright © 2015 Vladimir Tchernitski. All rights reserved.
//

#import "PayCardsRecognizer.h"


@implementation PayCardsRecognizer

- (instancetype _Nonnull)initWithDelegate:(id<PayCardsRecognizerPlatformDelegate> _Nonnull)delegate resultMode:(PayCardsRecognizerResultMode)resultMode container:(UIView * _Nonnull)container {
    self = [super init];
    return self;
}

- (instancetype _Nonnull)initWithDelegate:(id<PayCardsRecognizerPlatformDelegate> _Nonnull)delegate recognizerMode:(PayCardsRecognizerMode)recognizerMode resultMode:(PayCardsRecognizerResultMode)resultMode container:(UIView * _Nonnull)container {
    self = [super init];
    
    return self;
}

- (void)dealloc {

}

- (void)startCamera {}

- (void)startCameraWithOrientation:(UIInterfaceOrientation)orientation {}

- (void)stopCamera {}

- (void)pauseRecognizer {}

- (void)resumeRecognizer {}

- (void)setOrientation:(UIInterfaceOrientation)orientation {}

- (void)turnTorchOn:(BOOL)on withValue:(float)value {}

@end
