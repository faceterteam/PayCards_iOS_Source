//
//  WOEdgesWrapperView.h
//  CardRecognizer
//
//  Created by Vladimir Tchernitski on 10/03/16.
//  Copyright © 2016 Vladimir Tchernitski. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface WOEdgesWrapperView : UIView

@property(nonatomic,strong) UIView *topEdge;
@property(nonatomic,strong) UIView *bottomEdge;
@property(nonatomic,strong) UIView *leftEdge;
@property(nonatomic,strong) UIView *rightEdge;

- (instancetype)initWithColor:(UIColor *)color;

@end
