//
//  MKKeyboardView.m
//  GrainProc
//
//  Created by Mayank on 3/16/14.
//  Copyright (c) 2014 Mayank, Kurt. All rights reserved.
//

#import "MKKeyboardView.h"
#import <QuartzCore/QuartzCore.h>
#import "MKWhiteKeyView.h"

@interface MKKeyboardView()

@property (strong, nonatomic) NSMutableDictionary *pitchForTouch;

@end

@implementation MKKeyboardView

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

- (NSMutableDictionary *)pitchForTouch
{
    if (_pitchForTouch == nil)
    {
        _pitchForTouch = [[NSMutableDictionary alloc] init];
    }
    return _pitchForTouch;
}
-(void)layoutSubviews
{
    [self constructKeyboardView];
}

-(void)commonInit
{
    self.multipleTouchEnabled = YES;
    self.startPitch = 60;
    self.numPitches = 12;
    self.continousMode = YES;
    self.backgroundColor = [UIColor blackColor];
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
    CGFloat blackKeyHeight = self.bounds.size.height*0.6;
    CGFloat startX = 0;
    for (int i=0; i<self.numPitches; i++) {
        int currentPitch = self.startPitch + i;
        MKWhiteKeyView *view = [[MKWhiteKeyView alloc] init];
        view.tag = currentPitch;
        view.layer.masksToBounds = NO;
        view.layer.shadowOffset = CGSizeZero;
        if (![self blackKeyForPitch:currentPitch]) {
            //add white key
            view.frame = CGRectMake(startX, 0, whiteKeyWidth, self.bounds.size.height);
            view.layer.cornerRadius = whiteKeyWidth/8;
            [self insertSubview:view atIndex:0];
            view.backgroundColor = [UIColor whiteColor];
            startX += whiteKeyWidth;
            view.pressed = YES;
        } else {
            //add black key
            view.frame = CGRectMake(startX - (0.25)*whiteKeyWidth, 0, blackKeyWidth, blackKeyHeight);
            view.layer.cornerRadius = blackKeyWidth/4;
            view.layer.shadowRadius = 2;
            view.layer.shadowRadius = 7;
            view.layer.shadowOpacity = 0.75;
            [self addSubview:view];
            view.backgroundColor = [UIColor blackColor];
        }
        view.tag = currentPitch;
        [self releasedKeyWithPitch:currentPitch];
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

-(void)pressedKeyWithPitch:(int)pitch
{
    MKWhiteKeyView *view = (MKWhiteKeyView *)[self viewWithTag:pitch];
    if ([self blackKeyForPitch:pitch]) {
        view.layer.shadowRadius = 2;
    } else {
//        view.pressed = YES;
    }
}
-(void)releasedKeyWithPitch:(int)pitch
{
    MKWhiteKeyView *view = (MKWhiteKeyView *)[self viewWithTag:pitch];
    if ([self blackKeyForPitch:pitch]) {
        view.layer.shadowRadius = 2;
        view.layer.shadowRadius = 7;
        view.layer.shadowOpacity = 0.75;
    } else {
//        view.pressed = NO;
    }
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    float pitch = [self pitchForTouch:touch event:event];
    float y = [self yParamForTouch:touch event:event];
    if ([self.delegate respondsToSelector:@selector(keyboardViewTouchBegan:pitch:yParam:)]) {
        [self.delegate keyboardViewTouchBegan:touch pitch:pitch yParam:y];
    }
    [self.pitchForTouch setObject:[NSNumber numberWithInt:(int)pitch] forKey:[NSValue valueWithPointer:(__bridge const void *)(touch)]];
    [self pressedKeyWithPitch:pitch];
}

-(void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    float pitch = [self pitchForTouch:touch event:event];
    float y = [self yParamForTouch:touch event:event];
    if ([self.delegate respondsToSelector:@selector(keyboardViewTouchMoved:pitch:yParam:)]) {
        [self.delegate keyboardViewTouchMoved:touch pitch:pitch yParam:y];
    }

    int prevPitch = [[self.pitchForTouch objectForKey:[NSValue valueWithPointer:(__bridge const void *)(touch)]] intValue];
    if (pitch != prevPitch) {
        [self releasedKeyWithPitch:prevPitch];
        [self.pitchForTouch setObject:[NSNumber numberWithInt:(int)pitch] forKey:[NSValue valueWithPointer:(__bridge const void *)(touch)]];
        [self pressedKeyWithPitch:pitch];
    }
}

-(void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    float pitch = [self pitchForTouch:touch event:event];
    float y = [self yParamForTouch:touch event:event];
    if ([self.delegate respondsToSelector:@selector(keyboardViewTouchCancelled:pitch:yParam:)]) {
        [self.delegate keyboardViewTouchCancelled:touch pitch:pitch yParam:y];
    }
    [self touchesEnded:touches withEvent:event];
}

-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch = [touches anyObject];
    float pitch = [self pitchForTouch:touch event:event];
    float y = [self yParamForTouch:touch event:event];
    if ([self.delegate respondsToSelector:@selector(keyboardViewTouchEnded:pitch:yParam:)]) {
        [self.delegate keyboardViewTouchEnded:touch pitch:pitch yParam:y];
    }
    [self.pitchForTouch removeObjectForKey:[NSValue valueWithPointer:(__bridge const void *)(touch)]];
    [self releasedKeyWithPitch:pitch];
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
