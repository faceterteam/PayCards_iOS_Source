//
//  WOTorchDelegate.m
//  CardRecognizer
//
//  Created by Vladimir Tchernitski on 28/10/15.
//  Copyright © 2015 Vladimir Tchernitski. All rights reserved.
//

#import "WOTorchDelegate.h"
#import "PayCardsRecognizer.h"

@implementation WOTorchDelegate

bool ITorchDelegate::GetInstance(shared_ptr<ITorchDelegate> &torchDelegate, void* platformDelegate/* = NULL*/)
{
    torchDelegate = shared_ptr<ITorchDelegate>(new CTorchDelegate(platformDelegate));
    return torchDelegate != 0;
}

CTorchDelegate::CTorchDelegate( void* platformDelegate )// : self( NULL )
{
    self = (void*)CFBridgingRetain([[WOTorchDelegate alloc] initWithDelegate:(__bridge id<WOTorchPlatformDelegate>)platformDelegate]);
}

CTorchDelegate::~CTorchDelegate( void )
{
    CFBridgingRelease(self);
}

void CTorchDelegate::TorchStatusDidChange(bool status)
{
    [(__bridge WOTorchDelegate*)self torchStatusDidChange:status];
}

- (instancetype)initWithDelegate:(id<WOTorchPlatformDelegate>)platformDelegate
{
    self = [super init];
    
    if (self) {
        _delegate = platformDelegate;
    }
    
    return self;
}

- (void)torchStatusDidChange:(BOOL)status
{
    [_delegate torchStatusDidChange:status];
}

@end
