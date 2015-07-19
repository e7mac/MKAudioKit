//
//  MKWhiteKeyView.m
//  Pods
//
//  Created by Mayank on 4/11/14.
//
//

#import "MKWhiteKeyView.h"

@interface MKWhiteKeyView()

@property (nonatomic, strong) UIView *innerShadowView;

@end


@implementation MKWhiteKeyView {
    UIView *_shadowView;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

//- (UIView *)innerShadowView
//{
//    if (_innerShadowView == nil)
//    {
//        CGRect shadowRect = CGRectApplyAffineTransform(self.bounds, CGAffineTransformMakeScale(0.8, 1));
//        shadowRect = CGRectOffset(shadowRect, 0.1*self.bounds.size.width, 0);
//        _innerShadowView = [[UIView alloc] initWithFrame:shadowRect];
//        _innerShadowView.backgroundColor = [UIColor whiteColor];
//        _innerShadowView.layer.shadowOpacity = 1;
//        _innerShadowView.layer.shadowRadius = 5;
//        _innerShadowView.layer.shadowOpacity = 1;
//        _innerShadowView.layer.shadowOffset = CGSizeZero;
//        
//    }
//    return _innerShadowView;
//}
//-(void)setPressed:(BOOL)pressed
//{
//    _pressed = pressed;
//    if (pressed) {
//        [self addSubview:self.innerShadowView];
//        _innerShadowView.layer.cornerRadius = self.layer.cornerRadius;
//    } else {
//        [self.innerShadowView removeFromSuperview];
//    }
//}
//
///*
//// Only override drawRect: if you perform custom drawing.
//// An empty implementation adversely affects performance during animation.
//- (void)drawRect:(CGRect)rect
//{
//    // Drawing code
//}
//*/
//
@end
