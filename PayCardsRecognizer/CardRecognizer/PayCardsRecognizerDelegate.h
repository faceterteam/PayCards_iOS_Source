//
//  PayCardsRecognizerDelegate.h
//  CardRecognizer
//
//  Created by Vladimir Tchernitski on 13/01/16.
//  Copyright © 2016 Vladimir Tchernitski. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PayCardsRecognizer.h"

#import "IRecognitionCoreDelegate.h"
#import "IRecognitionResult.h"

#define NSSTRING(x)  [NSString stringWithUTF8String:x.c_str()]

class CRecognitionCoreDelegate : public IRecognitionCoreDelegate
{
public:
    
    CRecognitionCoreDelegate();
    ~CRecognitionCoreDelegate();
    
public:
    
    CRecognitionCoreDelegate( void* platformDelegate , void* recognizer);
    
    void RecognitionDidFinish(const shared_ptr<IRecognitionResult>& result, PayCardsRecognizerMode resultFlags);
    void CardImageDidExtract(cv::Mat cardImage);
        
private:
    void * self;
};

@interface PayCardsRecognizerDelegate : NSObject

@property (nonatomic, weak) id<PayCardsRecognizerPlatformDelegate> delegate;

@property (nonatomic, weak) PayCardsRecognizer *recognizer;

- (instancetype)initWithDelegate:(id<PayCardsRecognizerPlatformDelegate>)platformDelegate recognizer:(PayCardsRecognizer *)recognizer;

@end
