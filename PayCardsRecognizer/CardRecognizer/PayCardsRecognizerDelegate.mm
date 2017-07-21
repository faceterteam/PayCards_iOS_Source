//
//  PayCardsRecognizerDelegate.m
//  CardRecognizer
//
//  Created by Vladimir Tchernitski on 13/01/16.
//  Copyright © 2016 Vladimir Tchernitski. All rights reserved.
//

#import "PayCardsRecognizerDelegate.h"
#import "WOUtils.h"

#include "IRecognitionCore.h"
#include "IRecognitionResult.h"
#include "INeuralNetworkResult.h"
#include "INeuralNetworkResultList.h"
#include "IRecognitionCoreDelegate.h"

static const std::vector<string> alphabet = {" ","A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z"};

@interface PayCardsRecognizerResult ()

- (void)setData:(NSDictionary<NSString*, id> * _Nonnull)dictionary;

@end

@interface PayCardsRecognizerDelegate()

@property (nonatomic, strong) PayCardsRecognizerResult *result;

@end

@interface PayCardsRecognizer()

@property (nonatomic, assign) PayCardsRecognizerResultMode resultMode;

@property (nonatomic, assign) PayCardsRecognizerMode recognizerMode;

- (void)placeNumber:(NSString *)number;
- (void)placeDate:(NSString *)date;
- (void)placeName:(NSString *)name;

@end

@implementation PayCardsRecognizerDelegate

bool IRecognitionCoreDelegate::GetInstance(shared_ptr<IRecognitionCoreDelegate> &recognitionDelegate, void* platformDelegate/* = NULL*/, void* recognizer)
{
    recognitionDelegate = shared_ptr<CRecognitionCoreDelegate>(new CRecognitionCoreDelegate(platformDelegate, recognizer));
    return recognitionDelegate != 0;
}

CRecognitionCoreDelegate::CRecognitionCoreDelegate( void* platformDelegate, void* recognizer )// : self( NULL )
{
    self = (void*)CFBridgingRetain([[PayCardsRecognizerDelegate alloc] initWithDelegate:(__bridge id<PayCardsRecognizerPlatformDelegate>)platformDelegate recognizer: (__bridge PayCardsRecognizer *)recognizer]);
}

CRecognitionCoreDelegate::~CRecognitionCoreDelegate( void )
{
    CFBridgingRelease(self);
}

void CRecognitionCoreDelegate::RecognitionDidFinish(const std::shared_ptr<IRecognitionResult>& result,
                                                    PayCardsRecognizerMode resultFlags)
{
    [(__bridge PayCardsRecognizerDelegate*)self recognitionDidFinish:result flags:resultFlags];
}

void CRecognitionCoreDelegate::CardImageDidExtract(cv::Mat cardImage)
{
    [(__bridge PayCardsRecognizerDelegate*)self cardImageDidExtract:cardImage];
}

- (instancetype)initWithDelegate:(id<PayCardsRecognizerPlatformDelegate>)platformDelegate recognizer:(PayCardsRecognizer *)recognizer
{
    self = [super init];
    
    if (self) {
        _recognizer = recognizer;
        _delegate = platformDelegate;
    }
    
    return self;
}

- (void)recognitionDidFinish:(std::shared_ptr<IRecognitionResult>)result flags:(PayCardsRecognizerMode)flags
{
    
    if (_result == nil) {
        _result = [[PayCardsRecognizerResult alloc] init];
        _result.dictionary = [NSMutableDictionary<NSString*, id> dictionary];
    }
    
    NSMutableDictionary<NSString*, id> *resultDict = [NSMutableDictionary<NSString*, id> dictionaryWithDictionary:_result.dictionary];
//    NSMutableDictionary<NSString*, id> *resultDict = [NSMutableDictionary<NSString*, id> dictionary];
    
    UIImage *image = [WOUtils imageFromMat:result->GetCardImage()];
    
    if (image) {
        [resultDict setObject:image forKey:WOCardImage];
    }
    
    // number
    if (flags&PayCardsRecognizerModeNumber) {
        shared_ptr<INeuralNetworkResultList> numberResult = result->GetNumberResult();
        if (numberResult) {
            NSMutableString *numberStr = [NSMutableString string];
            NSMutableArray *numberConfidences = [NSMutableArray array];
            
            for (INeuralNetworkResultList::ResultIterator it = numberResult->Begin(); it != numberResult->End(); ++it) {
                shared_ptr<INeuralNetworkResult> result = *it;
                [numberStr appendFormat:@"%d", result->GetMaxIndex()];
                [numberConfidences addObject:[NSNumber numberWithFloat:result->GetMaxProbability()]];
            }
            
            [resultDict setObject:numberStr forKey:WOCardNumber];
            [resultDict setObject:numberConfidences forKey:WONumberConfidences];
            
            [resultDict setObject:[NSValue valueWithCGRect:CGRectMake(result->GetNumberRect().x, result->GetNumberRect().y, result->GetNumberRect().width, result->GetNumberRect().height)] forKey:WOPanRect];
            
//            dispatch_sync(dispatch_get_main_queue(), ^{
                [self.recognizer placeNumber:numberStr];
//            });
        }
    }

    //date
    if (flags&PayCardsRecognizerModeDate) {
        shared_ptr<INeuralNetworkResultList> dateResult = result->GetDateResult();
        if(dateResult) {
            NSMutableString *dateStr = [NSMutableString string];
            NSMutableArray *dateConfidences = [NSMutableArray array];
            
            for (INeuralNetworkResultList::ResultIterator it = dateResult->Begin(); it != dateResult->End(); ++it) {
                shared_ptr<INeuralNetworkResult> result = *it;
                [dateStr appendFormat:@"%d", result->GetMaxIndex()];
                [dateConfidences addObject:[NSNumber numberWithFloat:result->GetMaxProbability()]];
            }
            
            [resultDict setObject:dateStr forKey:WOExpDate];
            [resultDict setObject:dateConfidences forKey:WOExpDateConfidences];
            
            [resultDict setObject:[NSValue valueWithCGRect:CGRectMake(result->GetDateRect().x, result->GetDateRect().y, result->GetDateRect().width, result->GetDateRect().height)] forKey:WODateRect];
            
//            dispatch_sync(dispatch_get_main_queue(), ^{
                [self.recognizer placeDate:dateStr];
//            });
        }
    }
    
    // name
    if (flags&PayCardsRecognizerModeName) {
        std::string name = result->GetPostprocessedName();
        if (name.size() > 0) {
            [resultDict setObject:[NSString stringWithUTF8String:name.c_str()] forKey:WOHolderName];
        }
        
        shared_ptr<INeuralNetworkResultList> nameResult = result->GetNameResult();
        if (nameResult) {
            NSMutableString *nameStr = [NSMutableString string];
            NSMutableArray *nameConfidences = [NSMutableArray array];
            
            for (INeuralNetworkResultList::ResultIterator it = nameResult->Begin(); it != nameResult->End(); ++it) {
                shared_ptr<INeuralNetworkResult> result = *it;
                [nameStr appendFormat:@"%@", [NSString stringWithUTF8String:alphabet[result->GetMaxIndex()].c_str()]];
                [nameConfidences addObject:[NSNumber numberWithFloat:result->GetMaxProbability()]];
            }
            
            [resultDict setObject:nameStr forKey:WOHolderNameRaw];
            [resultDict setObject:nameConfidences forKey:WOHolderNameConfidences];
            
//            dispatch_sync(dispatch_get_main_queue(), ^{
                [self.recognizer placeName:[NSString stringWithUTF8String:name.c_str()]];
//            });
        }
    }
    
//    dispatch_sync(dispatch_get_main_queue(), ^{
    
        double delayInSeconds = 1;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        
        [_result setData:resultDict];
        
        if (_recognizer.resultMode == PayCardsRecognizerResultModeAsync) {
            if (flags&PayCardsRecognizerModeName || !_recognizer.recognizerMode&PayCardsRecognizerModeName) {
                _result.isCompleted = true;
            }
            
            if (_result.isCompleted) {
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    [_delegate payCardsRecognizer:_recognizer didRecognize:_result];
                    _result = nil;
                });
            } else {
                [_delegate payCardsRecognizer:_recognizer didRecognize:_result];
            }
            
            
        } else if (_recognizer.resultMode == PayCardsRecognizerResultModeSync) {
            
            BOOL numberIsFilled = YES;
            BOOL exirationIsFilled = YES;
            BOOL nameIsFilled = YES;
            BOOL imageIsFilled = YES;
            
            if (_recognizer.recognizerMode&PayCardsRecognizerModeNumber) {
                if (_result.recognizedNumber.length == 0) {
                    numberIsFilled = NO;
                }
            }
            
            if (_recognizer.recognizerMode&PayCardsRecognizerModeDate) {
                if (_result.recognizedExpireDateMonth.length == 0) {
                    exirationIsFilled = NO;
                }
            }
            
            if (_recognizer.recognizerMode&PayCardsRecognizerModeName) {
                if (!flags&PayCardsRecognizerModeName) {
                    nameIsFilled = NO;
                }
            }
            
            if (_recognizer.recognizerMode&PayCardsRecognizerModeGrabCardImage) {
                if (_result.image == nil) {
                    imageIsFilled = NO;
                }
            }
            
            if (numberIsFilled && exirationIsFilled && nameIsFilled) {
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    [_delegate payCardsRecognizer:_recognizer didRecognize:_result];
                    if (_result.isCompleted) {
                        _result = nil;
                    }
                });
            }
        }
//    });
}

- (void)cardImageDidExtract:(cv::Mat)cardImage
{
//    UIImage *image = [WOUtils imageFromMat:cardImage];
//    
//    dispatch_sync(dispatch_get_main_queue(), ^{
//        [_delegate cardImageDidExtract:image];
//    });
}

@end
