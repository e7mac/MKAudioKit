//
//  AudioController.h
//  GrainProc
//
//  Created by Kurt Werner on 9/22/13.
//  Copyright (c) 2013 Mayank, Kurt. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <Audiobus.h>
#import <AVFoundation/AVFoundation.h>

typedef struct {
  AudioUnit rioUnit;
  AudioStreamBasicDescription asbd;
  ABFilterPort *filterPort;
  ABSenderPort *audiobusOutputPort;
  BOOL audioSetupDone;
  BOOL hasFilterPort;
  __block void (^processBlock)(AudioBufferList* ioData, UInt32 inNumberFrames, AudioTimeStamp *timestamp);
} AudioState;

@interface AudioController: NSObject

+ (id)sharedInstance;

@property (assign, nonatomic) Float64 hardwareSampleRate;
@property (nonatomic) AudioState audioState;
@property (nonatomic)  BOOL running;
@property (strong, nonatomic) ABAudiobusController *audiobusController;


-(void)setupAudioSessionRequestingSampleRate:(int)requestedSampleRate;
-(void)setupProcessBlockWithAudioCallback:(void (^)(AudioBufferList* ioData, UInt32 inNumberFrames, AudioTimeStamp *timestamp, AudioStreamBasicDescription asbd))audioBlock;
-(void)setupAudiobusWithKey:(NSString *)apiKey withOutputPort:(NSDictionary *)outputDescription outputPortDescription:(AudioComponentDescription)outputPortDescription filterPort:(NSDictionary *)filterDescription filterPortDescription:(AudioComponentDescription)filterPortDescription;

-(void)setupDone;

-(void)start;
-(void)stop;

@end