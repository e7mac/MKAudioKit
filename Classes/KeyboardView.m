//
//  KeyboardView.m
//  GrainProc
//
//  Created by Mayank on 3/16/14.
//  Copyright (c) 2014 Mayank, Kurt. All rights reserved.
//

#import "KeyboardView.h"

@implementation KeyboardView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        [self commonInit];
    }
    return self;
}


-(void)commonInit
{
    self.multipleTouchEnabled = YES;
    self.startPitch = 60;
    self.numPitches = 12;
    self.continousMode = YES;
    [self constructKeyboardView];
}

-(void)setStartPitch:(int)startPitch
{
    _startPitch = startPitch;
    [self constructKeyboardView];
}

-(void)setNumPitches:(int)numPitches
{
    _numPitches = numPitches;
    [self constructKeyboardView];
}

-(void)constructKeyboardView
{
    [[self subviews]
     makeObjectsPerformSelector:@selector(removeFromSuperview)];
    int whiteKeys = 0;
    for (int i=0; i<self.numPitches; i++) {
        int currentPitch = self.startPitch + i;
        whiteKeys += ![self blackKeyForPitch:currentPitch];
    }
    CGFloat whiteKeyWidth = self.bounds.size.width / whiteKeys;
    CGFloat blackKeyWidth = 0.5 * whiteKeyWidth;
    CGFloat startX = 0;
    for (int i=0; i<self.numPitches; i++) {
        int currentPitch = self.startPitch + i;
        UIView *view = [[UIView alloc] init];
        view.tag = currentPitch;
        if (![self blackKeyForPitch:currentPitch]) {
            //add white key
            view.frame = CGRectMake(startX, 0, whiteKeyWidth, self.bounds.size.height);
            [self insertSubview:view atIndex:0];
            startX += whiteKeyWidth;
        } else {
            //add black key
            view.frame = CGRectMake(startX - (0.25)*whiteKeyWidth, 0, blackKeyWidth, self.bounds.size.height*0.6);
            [self addSubview:view];
            view.backgroundColor = [UIColor blackColor];
        }
        view.tag = currentPitch;
        view.layer.borderColor = [[UIColor blackColor] CGColor];
        view.layer.borderWidth = 2;
    }
}

-(BOOL)blackKeyForPitch:(int)pitch
{
    pitch = pitch%12;
    switch (pitch) {
        case 1:
        case 3:
        case 6:
        case 8:
        case 10:
            return YES;
            break;
        case 0:
        case 2:
        case 4:
        case 5:
        case 7:
        case 9:
        case 11:
        default:
            return NO;
            break;
    }
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    float pitch = [self pitchForTouch:touch event:event];
    float y = [self yParamForTouch:touch event:event];
    if ([self.delegate respondsToSelector:@selector(keyboardTouchBegan:pitch:yParam:)]) {
        [self.delegate keyboardTouchBegan:touch pitch:pitch yParam:y];
    }
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    float pitch = [self pitchForTouch:touch event:event];
    float y = [self yParamForTouch:touch event:event];
    if ([self.delegate respondsToSelector:@selector(keyboardTouchMoved:pitch:yParam:)]) {
        [self.delegate keyboardTouchMoved:touch pitch:pitch yParam:y];
    }
}

-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    float pitch = [self pitchForTouch:touch event:event];
    float y = [self yParamForTouch:touch event:event];
    if ([self.delegate respondsToSelector:@selector(keyboardTouchCancelled:pitch:yParam:)]) {
        [self.delegate keyboardTouchCancelled:touch pitch:pitch yParam:y];
    }
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    float pitch = [self pitchForTouch:touch event:event];
    float y = [self yParamForTouch:touch event:event];
    if ([self.delegate respondsToSelector:@selector(keyboardTouchEnded:pitch:yParam:)]) {
        [self.delegate keyboardTouchEnded:touch pitch:pitch yParam:y];
    }
}

-(float)pitchForTouch:(UITouch *)touch event:(UIEvent *)event
{
    CGPoint touchPoint = [touch locationInView:self];
    UIView *touchedView = [self hitTest:touchPoint withEvent:event];
    int viewPitchTag = touchedView.tag;
    float pitch = viewPitchTag;
    if (self.continousMode) {
        CGPoint point = [touch locationInView:touchedView];
        float fractionalPitch = point.x / touchedView.bounds.size.width;
        pitch += fractionalPitch;
    }
    return pitch;
}

-(float)yParamForTouch:(UITouch *)touch event:(UIEvent *)event
{
    CGPoint touchPoint = [touch locationInView:self];
    UIView *touchedView = [self hitTest:touchPoint withEvent:event];
    CGPoint point = [touch locationInView:touchedView];
    float fractionalPitch = point.y / touchedView.bounds.size.height;
    return fractionalPitch;
}

@end
