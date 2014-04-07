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

typedef struct {
	AudioUnit rioUnit;
	AudioStreamBasicDescription asbd;
    ABFilterPort *filterPort;
    ABOutputPort *audiobusOutputPort;
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
@property (strong, nonatomic) ABAudiobusAudioUnitWrapper *audiobusAudioUnitWrapper;


-(void)setupAudioSessionRequestingSampleRate:(int)requestedSampleRate;
-(void)setupProcessBlockWithAudioCallback:(void (^)(AudioBufferList* ioData, UInt32 inNumberFrames, AudioTimeStamp *timestamp, AudioStreamBasicDescription asbd))audioBlock;
-(void)setupAudiobusLaunchUrl:(NSURL *)launchUrl WithKey:(NSString *)apiKey withFilterPort:(BOOL)hasFilterPort;

-(void)setupDone;

-(void)start;
-(void)stop;

@end