//
//  PayCardsRecognizerResult.m
//  PayCardsRecognizer
//
//  Created by Vitaliy Kuzmenko on 12/07/2017.
//  Copyright © 2017 Wallet One. All rights reserved.
//

#import "PayCardsRecognizerResult.h"
#import "PayCardsRecognizer.h"

@implementation PayCardsRecognizerResult

- (NSString *)description
{
    return [NSString stringWithFormat:@"Number:%@, Rect:%@ Name:%@, Expiration:%@/%@ Image:%@", self.recognizedNumber, NSStringFromCGRect(self.recognizedNumberRect), self.recognizedHolderName, self.recognizedExpireDateMonth, self.recognizedExpireDateYear, self.image];
}

- (void)setData:(NSDictionary<NSString*, id> * _Nonnull)dictionary
{
    self.dictionary = dictionary;
    
    self.recognizedNumber = dictionary[WOCardNumber];
    self.recognizedHolderName = dictionary[WOHolderName];
    
    NSString *expiration = dictionary[WOExpDate];
    
    self.recognizedExpireDateMonth = [expiration substringWithRange:NSMakeRange(0, 2)];
    self.recognizedExpireDateYear = [expiration substringWithRange:NSMakeRange(2, 2)];
    
    NSValue *value = dictionary[WOPanRect];
    
    self.recognizedNumberRect = value.CGRectValue;
}

@end
