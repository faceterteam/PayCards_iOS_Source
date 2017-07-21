//
//  PayCardsRecognizer.m
//  CardRecognizer
//
//  Created by Vladimir Tchernitski on 04/12/15.
//  Copyright © 2015 Vladimir Tchernitski. All rights reserved.
//

#import "PayCardsRecognizer.h"
#import <UIKit/UIKit.h>

@implementation UIView (AutolayoutSim)

- (NSLayoutConstraint *)addConstraintWithItem:(UIView *)item attribute:(NSLayoutAttribute)attr {
    return [self addConstraintWithItem:item attribute:attr toItem:self];
}

- (NSLayoutConstraint *)addConstraintWithItem:(UIView *)item attribute:(NSLayoutAttribute)attr toItem:(UIView *)toItem {
    return [self addConstraintWithItem:item attribute:attr toItem:toItem attribute:attr];
}

- (NSLayoutConstraint *)addConstraintWithItem:(UIView *)item attribute:(NSLayoutAttribute)attr1 toItem:(UIView *)toItem attribute:(NSLayoutAttribute)attr2 {
    return [self addConstraintWithItem:item attribute:attr1 toItem:toItem attribute:attr2 constant: 0.0];
}

- (NSLayoutConstraint *)addConstraintWithItem:(UIView *)item attribute:(NSLayoutAttribute)attr1 toItem:(UIView *)toItem attribute:(NSLayoutAttribute)attr2 constant:(CGFloat)constant {
    NSLayoutConstraint *constraint = [NSLayoutConstraint constraintWithItem:item attribute:attr1 relatedBy:NSLayoutRelationEqual toItem:toItem attribute:attr2 multiplier:1.0 constant:constant];
    [self addConstraint:constraint];
    return constraint;
}

@end

@interface PayCardsRecognizer ()

@property (nonatomic, strong) UIView *simulatorView;

@property (nonatomic, weak) UIView *container;

@end

@implementation PayCardsRecognizer

- (instancetype _Nonnull)initWithDelegate:(id<PayCardsRecognizerPlatformDelegate> _Nonnull)delegate resultMode:(PayCardsRecognizerResultMode)resultMode container:(UIView * _Nonnull)container {
    self = [super init];
    self.container = container;
    
    [self.container addSubview:self.simulatorView];
    [self autoPinSimulatorViewToContainer];
    
    return self;
}

- (instancetype _Nonnull)initWithDelegate:(id<PayCardsRecognizerPlatformDelegate> _Nonnull)delegate recognizerMode:(PayCardsRecognizerDataMode)recognizerMode resultMode:(PayCardsRecognizerResultMode)resultMode container:(UIView * _Nonnull)container {
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

- (UIView *)simulatorView {
    if (_simulatorView) {
        return _simulatorView;
    }
    
    _simulatorView = [[UIView alloc] initWithFrame:self.container.bounds];
    _simulatorView.backgroundColor = [UIColor colorWithRed:0.937 green:0.937 blue:0.957 alpha:1];
    _simulatorView.translatesAutoresizingMaskIntoConstraints = NO;
    
    UILabel *label = [[UILabel alloc] init];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.numberOfLines = 0;
    label.text = NSLocalizedString(@"Recognizer is not available in simulator", nil);
    label.textColor = [UIColor darkGrayColor];
    label.textAlignment = NSTextAlignmentCenter;
    
    UIView *holder = [[UIView alloc] init];
    holder.translatesAutoresizingMaskIntoConstraints = NO;
    holder.backgroundColor = [UIColor clearColor];
    
    [holder addSubview:label];
    [holder addSubview:button];
    
    [_simulatorView addSubview:holder];
    
    [holder addConstraintWithItem:label attribute:NSLayoutAttributeTop];
    [holder addConstraintWithItem:label attribute:NSLayoutAttributeRight];
    [holder addConstraintWithItem:label attribute:NSLayoutAttributeLeft];
    
    [holder addConstraintWithItem:button attribute:NSLayoutAttributeBottom];
    [holder addConstraintWithItem:button attribute:NSLayoutAttributeRight];
    [holder addConstraintWithItem:button attribute:NSLayoutAttributeLeft];
    
    [holder addConstraintWithItem:button attribute:NSLayoutAttributeTop toItem:label attribute:NSLayoutAttributeBottom constant: 8.0];
    
    [_simulatorView addConstraintWithItem:holder attribute:NSLayoutAttributeCenterY];
    [_simulatorView addConstraintWithItem:holder attribute:NSLayoutAttributeLeft toItem:_simulatorView attribute:NSLayoutAttributeLeft constant: 15.0];
    [_simulatorView addConstraintWithItem:_simulatorView attribute:NSLayoutAttributeRight toItem:holder attribute:NSLayoutAttributeRight constant: 15.0];
    
    return _simulatorView;
}

- (void)autoPinSimulatorViewToContainer {
    [self.container addConstraintWithItem:self.simulatorView attribute:NSLayoutAttributeTop];
    [self.container addConstraintWithItem:self.simulatorView attribute:NSLayoutAttributeRight];
    [self.container addConstraintWithItem:self.simulatorView attribute:NSLayoutAttributeBottom];
    [self.container addConstraintWithItem:self.simulatorView attribute:NSLayoutAttributeLeft];
}


@end
