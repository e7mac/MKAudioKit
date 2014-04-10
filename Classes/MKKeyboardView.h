//
//  MKKeyboardView.h
//  GrainProc
//
//  Created by Mayank on 3/16/14.
//  Copyright (c) 2014 Mayank, Kurt. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol MKKeyboardViewDelegate <NSObject>

@optional
-(void)keyboardViewTouchBegan:(UITouch *)touch pitch:(float)pitch yParam:(float)y;
-(void)keyboardViewTouchMoved:(UITouch *)touch pitch:(float)pitch yParam:(float)y;;
-(void)keyboardViewTouchCancelled:(UITouch *)touch pitch:(float)pitch yParam:(float)y;;
-(void)keyboardViewTouchEnded:(UITouch *)touch pitch:(float)pitch yParam:(float)y;;

@end

@interface MKKeyboardView : UIView

@property (weak, nonatomic) id<MKKeyboardViewDelegate> delegate;
@property (assign, nonatomic) int startPitch;
@property (assign, nonatomic) int numPitches;
@property (assign, nonatomic) BOOL continousMode;

@end
