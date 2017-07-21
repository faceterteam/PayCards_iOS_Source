//
//  WOTorchDelegate.h
//  CardRecognizer
//
//  Created by Vladimir Tchernitski on 28/10/15.
//  Copyright © 2015 Vladimir Tchernitski. All rights reserved.
//

#include <memory>
#include "ITorchDelegate.h"

#import <Foundation/Foundation.h>
#import "PayCardsRecognizer.h"

@protocol WOTorchPlatformDelegate

- (void)torchStatusDidChange:(BOOL)status;

@end

class CTorchDelegate : public ITorchDelegate/*, public enable_shared_from_this<ITorchDelegate>*/
{
public:
    
    CTorchDelegate();
    ~CTorchDelegate();
    
public:
    
    CTorchDelegate( void* platformDelegate );
    
    void TorchStatusDidChange(bool flag);
    
private:
    void *self;
};

@interface WOTorchDelegate : NSObject

@property(nonatomic,weak) id<WOTorchPlatformDelegate> delegate;

- (instancetype)initWithDelegate:(id<WOTorchPlatformDelegate>)platformDelegate;

@end
