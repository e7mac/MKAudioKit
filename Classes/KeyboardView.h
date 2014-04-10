//
//  KeyboardView.h
//  GrainProc
//
//  Created by Mayank on 3/16/14.
//  Copyright (c) 2014 Mayank, Kurt. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol KeyboardViewDelegate <NSObject>

@optional
-(void)keyboardTouchBegan:(UITouch *)touch pitch:(float)pitch yParam:(float)y;
-(void)keyboardTouchMoved:(UITouch *)touch pitch:(float)pitch yParam:(float)y;;
-(void)keyboardTouchCancelled:(UITouch *)touch pitch:(float)pitch yParam:(float)y;;
-(void)keyboardTouchEnded:(UITouch *)touch pitch:(float)pitch yParam:(float)y;;

@end

@interface KeyboardView : UIView

@property (weak, nonatomic) id<KeyboardViewDelegate> delegate;
@property (assign, nonatomic) int startPitch;
@property (assign, nonatomic) int numPitches;
@property (assign, nonatomic) BOOL continousMode;

@end
