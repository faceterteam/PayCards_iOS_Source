//
//  WOEdgesWrapperView.m
//  CardRecognizer
//
//  Created by Vladimir Tchernitski on 10/03/16.
//  Copyright © 2016 Vladimir Tchernitski. All rights reserved.
//

#import "WOEdgesWrapperView.h"

static const float kEdgesCornerPadding = 50.0;
static const float kThickness = 5.0;

@implementation WOEdgesWrapperView

- (instancetype)initWithColor:(UIColor *)color
{
    self = [super init];
    if(self) {
        self.backgroundColor = [UIColor clearColor];//[UIColor colorWithRed:182.0/255.0 green:255.0/255.0 blue:102.0/255.0 alpha:1.0];
        self.frame = CGRectMake(0, 0, 5., 5.);
        self.translatesAutoresizingMaskIntoConstraints = NO;
        
        _topEdge = [UIView new];
        _topEdge.backgroundColor = color;
        _topEdge.layer.cornerRadius = kThickness / 2;
        
        [self addSubview:_topEdge];
        
        _bottomEdge = [UIView new];
        _bottomEdge.backgroundColor = color;
        _bottomEdge.layer.cornerRadius = kThickness / 2;
        
        [self addSubview:_bottomEdge];
        
        _leftEdge = [UIView new];
        _leftEdge.backgroundColor = color;
        _leftEdge.layer.cornerRadius = kThickness / 2;
        
        [self addSubview:_leftEdge];
        
        _rightEdge = [UIView new];
        _rightEdge.backgroundColor = color;
        _rightEdge.layer.cornerRadius = kThickness / 2;
        
        [self addSubview:_rightEdge];
    }
    
    return self;
}

- (void)layoutSubviews
{
    _topEdge.frame = CGRectMake(kEdgesCornerPadding, 0, self.frame.size.width-kEdgesCornerPadding*2, kThickness);
    _bottomEdge.frame = CGRectMake(kEdgesCornerPadding, self.frame.size.height-kThickness, self.frame.size.width-kEdgesCornerPadding*2, kThickness);
    _leftEdge.frame = CGRectMake(0, kEdgesCornerPadding, kThickness, self.frame.size.height-kEdgesCornerPadding*2);
    _rightEdge.frame = CGRectMake(self.frame.size.width-kThickness, kEdgesCornerPadding, kThickness, self.frame.size.height-kEdgesCornerPadding*2);
}

@end
