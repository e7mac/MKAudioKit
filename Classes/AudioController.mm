//
//  AudioController.m
//  GrainProc
//
//  Created by Kurt Werner on 9/22/13.
//  Copyright (c) 2013 Mayank, Kurt. All rights reserved.
//

#import "AudioController.h"

void CheckError(OSStatus error, const char *operation)
{
	if (error == noErr) return;
	char str[20];
	// see if it appears to be a 4-char-code
	*(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
        if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4])) {
            str[0] = str[5] = '\'';
            str[6] = '\0';
        } else
            // no, format it as an integer
            sprintf(str, "%d", (int)error);
	fprintf(stderr, "Error: %s (%s)\n", operation, str);
	exit(1);
}

#pragma mark callbacks
void MyInterruptionListener (void *inUserData,
                             UInt32 inInterruptionState) {
	printf ("Interrupted! inInterruptionState=%ld\n", inInterruptionState);
	AudioController *audioController = (__bridge AudioController*)inUserData;
	switch (inInterruptionState) {
		case kAudioSessionBeginInterruption:
            break;
		case kAudioSessionEndInterruption:
			// TODO: doesn't work!
        {
			CheckError(AudioSessionSetActive(true),
					   "Couldn't set audio session active");
			CheckError (AudioOutputUnitStart (audioController.audioState.rioUnit),
						"Couldn't start RIO unit");
            UInt32 allowMixing = YES;
            AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryMixWithOthers, sizeof (allowMixing), &allowMixing);
        }
            break;
		default:
			break;
	};
}

void audioRouteChangeListenerCallback (
                                       void                   *inUserData,                                 // 1
                                       AudioSessionPropertyID inPropertyID,                                // 2
                                       UInt32                 inPropertyValueSize,                         // 3
                                       const void             *inPropertyValue                             // 4
) {
    if (inPropertyID != kAudioSessionProperty_AudioRouteChange) return; // 5
    
    CFDictionaryRef routeChangeDictionary = (CFDictionaryRef)inPropertyValue;        // 8
    CFNumberRef routeChangeReasonRef =
    (CFNumberRef) CFDictionaryGetValue (
                                        routeChangeDictionary,
                                        CFSTR (kAudioSession_AudioRouteChangeKey_Reason)
                                        );
    
    SInt32 routeChangeReason;
    CFNumberGetValue (
                      routeChangeReasonRef, kCFNumberSInt32Type, &routeChangeReason
                      );
    
    //headphones taken out
    if (routeChangeReason ==
        kAudioSessionRouteChangeReason_OldDeviceUnavailable) {  // 9
        UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;  // 1
        
        AudioSessionSetProperty (
                                 kAudioSessionProperty_OverrideAudioRoute,                         // 2
                                 sizeof (audioRouteOverride),                                      // 3
                                 &audioRouteOverride                                               // 4
                                 );
        
    }
    //headphones plugged
    if (routeChangeReason ==
        kAudioSessionRouteChangeReason_NewDeviceAvailable) {  // 9
        UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_None;  // 1
        
        AudioSessionSetProperty (
                                 kAudioSessionProperty_OverrideAudioRoute,                         // 2
                                 sizeof (audioRouteOverride),                                      // 3
                                 &audioRouteOverride                                               // 4
                                 );
        
    }
    UInt32 allowMixing = YES;
    AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryMixWithOthers, sizeof (allowMixing), &allowMixing);
}

OSStatus GranularSynthRenderCallback (
                                      void *							inRefCon,
                                      AudioUnitRenderActionFlags *	ioActionFlags,
                                      const AudioTimeStamp *			inTimeStamp,
                                      UInt32							inBusNumber,
                                      UInt32							inNumberFrames,
                                      AudioBufferList *				ioData) {
	AudioState *audioState = (AudioState*) inRefCon;
    
    if (!audioState->audioSetupDone)
        return noErr;
	// just copy samples
	UInt32 bus1 = 1;
	CheckError(AudioUnitRender(audioState->rioUnit,
                               ioActionFlags,
                               inTimeStamp,
                               bus1,
                               inNumberFrames,
                               ioData),
			   "Couldn't render from RemoteIO unit");
	// walk the samples
    if ( audioState->hasFilterPort ) {
        if ( ABFilterPortIsConnected(audioState->filterPort)) {
            // Pull output audio from the filter port
            // Note: The following line isn't necessary if you're using the Audio Unit Wrapper - it'll do this for you.
            ABFilterPortGetOutput(audioState->filterPort, ioData, inNumberFrames, NULL);
            return noErr;
        }
    }
    audioState->processBlock(ioData, inNumberFrames, NULL);
	return noErr;
}

@interface AudioController()
{
    void (^processBlock)(AudioBufferList* ioData, UInt32 inNumberFrames, AudioTimeStamp *timestamp);
}
@end


@implementation AudioController

static NSMutableDictionary* instances = nil;

+ (id)sharedInstance
{
	if (!instances) {
		instances = [[NSMutableDictionary alloc] init];
	}
	id instance = [instances objectForKey:self];
	if (!instance) {
		instance = [[self alloc] init];
		[instances setObject:instance forKey:(id<NSCopying>)self];
	}
	return instance;
}

-(id)init
{
    self = [super init];
    if (self) {
        _running = NO;
    }
    return self;
}


-(void)setupProcessBlockWithAudioCallback:(void (^)(AudioBufferList* ioData, UInt32 inNumberFrames, AudioTimeStamp *timestamp, AudioStreamBasicDescription asbd))audioBlock
{
    typeof(self) weakSelf = self;
    processBlock = ^(AudioBufferList* ioData, UInt32 inNumberFrames, AudioTimeStamp *timestamp) {
        // Filter the audio...
        audioBlock(ioData,inNumberFrames,timestamp,weakSelf.audioState.asbd);
        
    };
    _audioState.processBlock = processBlock;
}


-(void)start {
    if(!_running) {
        CheckError (AudioOutputUnitStart (_audioState.rioUnit),
                    "couldn't start RIO unit");
        _running = YES;
    }
}

-(void)stop {
    if(_running) {
        CheckError (AudioOutputUnitStop (_audioState.rioUnit),
                    "couldn't stop RIO unit");
        _running = NO;
    }
}

-(void)setupAudioSessionRequestingSampleRate:(int)requestedSampleRate
{
    CheckError(AudioSessionInitialize(NULL,
                                      kCFRunLoopDefaultMode,
                                      MyInterruptionListener,
                                      (__bridge void *)(self)),
               "couldn't initialize audio session");
    
    UInt32 category = kAudioSessionCategory_PlayAndRecord;
    CheckError(AudioSessionSetProperty(kAudioSessionProperty_AudioCategory,
                                       sizeof(category),
                                       &category),
               "Couldn't set category on audio session");
    
    // route audio to bottom speaker for iphone
    
    if ([[UIDevice currentDevice].model isEqualToString:@"iPhone"])
    {
        UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;  // 1
        
        AudioSessionSetProperty (
                                 kAudioSessionProperty_OverrideAudioRoute,                         // 2
                                 sizeof (audioRouteOverride),                                      // 3
                                 &audioRouteOverride                                               // 4
                                 );
        
        
        AudioSessionPropertyID routeChangeID =
        kAudioSessionProperty_AudioRouteChange;    // 1
        AudioSessionAddPropertyListener (                                  // 2
                                         routeChangeID,                                                 // 3
                                         audioRouteChangeListenerCallback,                                      // 4
                                         nil                                                       // 5
                                         );
        
        
    }
    
    Float32 preferredBufferDuration = 0.01;                      // 1
    CheckError(AudioSessionSetProperty (                                     // 2
                                        kAudioSessionProperty_PreferredHardwareIOBufferDuration,
                                        sizeof (preferredBufferDuration),
                                        &preferredBufferDuration
                                        ),
               "couldn't set buffer duration");
    
    
    UInt32 allowMixing = YES;
    AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryMixWithOthers, sizeof (allowMixing), &allowMixing);
    
    
    Float64 requestSampleRateStoredInVariable = (Float64)requestedSampleRate;
    UInt32 propSize = sizeof (requestSampleRateStoredInVariable);
    CheckError(AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareSampleRate,
                                       propSize,
                                       &requestSampleRateStoredInVariable),
               "Couldn't set hardwareSampleRate");
    
    // is audio input available?
    UInt32 ui32PropertySize = sizeof (UInt32);
    UInt32 inputAvailable;
    CheckError(AudioSessionGetProperty(kAudioSessionProperty_AudioInputAvailable,
                                       &ui32PropertySize,
                                       &inputAvailable),
               "Couldn't get current audio input available prop");
    if (! inputAvailable) {
        UIAlertView *noInputAlert =
        [[UIAlertView alloc] initWithTitle:@"No audio input"
                                   message:@"No audio input device is currently attached"
                                  delegate:nil
                         cancelButtonTitle:@"OK"
                         otherButtonTitles:nil];
        [noInputAlert show];
        // TODO: do we have to die? couldn't we tolerate an incoming connection
        // TODO: need another example to show audio routes?
    }
    
    // inspect the hardware input rate
    
    propSize = sizeof (_hardwareSampleRate);
    CheckError(AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate,
                                       &propSize,
                                       &_hardwareSampleRate),
               "Couldn't get hardwareSampleRate");
    NSLog (@"hardwareSampleRate = %f", _hardwareSampleRate);
    
    //    NSAssert(hardwareSampleRate == SRATE, "sample rate 44100 not supported");
    //	CheckError(AudioSessionSetActive(true),
    //			   "Couldn't set AudioSession active");
    
    // describe unit
    AudioComponentDescription audioCompDesc;
    audioCompDesc.componentType = kAudioUnitType_Output;
    audioCompDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioCompDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioCompDesc.componentFlags = 0;
    audioCompDesc.componentFlagsMask = 0;
    
    // get rio unit from audio component manager
    AudioComponent rioComponent = AudioComponentFindNext(NULL, &audioCompDesc);
    CheckError(AudioComponentInstanceNew(rioComponent, &_audioState.rioUnit),
               "Couldn't get RIO unit instance");
    
    // set up the rio unit for playback
    UInt32 oneFlag = 1;
    AudioUnitElement bus0 = 0;
    CheckError(AudioUnitSetProperty (_audioState.rioUnit,
                                     kAudioOutputUnitProperty_EnableIO,
                                     kAudioUnitScope_Output,
                                     bus0,
                                     &oneFlag,
                                     sizeof(oneFlag)),
               "Couldn't enable RIO output");
    
    // enable rio input
    AudioUnitElement bus1 = 1;
    CheckError(AudioUnitSetProperty(_audioState.rioUnit,
                                    kAudioOutputUnitProperty_EnableIO,
                                    kAudioUnitScope_Input,
                                    bus1,
                                    &oneFlag,
                                    sizeof(oneFlag)),
               "Couldn't enable RIO input");
    
    
    // setup an asbd in the iphone canonical format
    AudioStreamBasicDescription myASBD;
    memset (&myASBD, 0, sizeof (myASBD));
    myASBD.mSampleRate = _hardwareSampleRate;
    myASBD.mFormatID = kAudioFormatLinearPCM;
    myASBD.mFormatFlags = kAudioFormatFlagsCanonical;
    myASBD.mBytesPerPacket = 4;
    myASBD.mFramesPerPacket = 1;
    myASBD.mBytesPerFrame = 4;
    myASBD.mChannelsPerFrame = 2;
    myASBD.mBitsPerChannel = 16;
    
    /*
     // set format for output (bus 0) on rio's input scope
     */
    CheckError(AudioUnitSetProperty (_audioState.rioUnit,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Input,
                                     bus0,
                                     &myASBD,
                                     sizeof (myASBD)),
               "Couldn't set ASBD for RIO on input scope / bus 0");
    
    
    // set asbd for mic input
    CheckError(AudioUnitSetProperty (_audioState.rioUnit,
                                     kAudioUnitProperty_StreamFormat,
                                     kAudioUnitScope_Output,
                                     bus1,
                                     &myASBD,
                                     sizeof (myASBD)),
               "Couldn't set ASBD for RIO on output scope / bus 1");
    
    _audioState.asbd = myASBD;
    
    // set callback method
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = GranularSynthRenderCallback; // callback function
    callbackStruct.inputProcRefCon = &_audioState;
    
    CheckError(AudioUnitSetProperty(_audioState.rioUnit,
                                    kAudioUnitProperty_SetRenderCallback,
                                    kAudioUnitScope_Global,
                                    bus0,
                                    &callbackStruct,
                                    sizeof (callbackStruct)),
               "Couldn't set RIO render callback on bus 0");
    // initialize and start remoteio unit
    CheckError(AudioUnitInitialize(_audioState.rioUnit),
               "Couldn't initialize RIO unit");
    [self start];
}



-(void)setupDone
{
    _audioState.audioSetupDone = YES;
}

#pragma mark Audiobus things
-(void)setupAudiobusLaunchUrl:(NSURL *)launchUrl WithKey:(NSString *)apiKey withFilterPort:(BOOL)hasFilterPort
{
    self.audiobusController = [[ABAudiobusController alloc]
                               initWithAppLaunchURL:launchUrl
                               apiKey:apiKey];
    
    self.audiobusAudioUnitWrapper = [[ABAudiobusAudioUnitWrapper alloc]
                                     initWithAudiobusController:self.audiobusController
                                     audioUnit:self.audioState.rioUnit
                                     output:[self.audiobusController addOutputPortNamed:@"Audio Output"
                                                                                  title:NSLocalizedString(@"Main App Output", @"")]
                                     input:nil];
    self.audiobusAudioUnitWrapper.useLowLatencyInputStream = YES;
    UInt32 allowMixing = YES;
    AudioSessionSetProperty(kAudioSessionProperty_OverrideCategoryMixWithOthers, sizeof (allowMixing), &allowMixing);
    
    _audioState.hasFilterPort = hasFilterPort;
    if (hasFilterPort) {
        // In app initialisation...
        _audioState.filterPort = [_audiobusController addFilterPortNamed:@"Main"
                                                                    title:@"Main Filter"
                                                             processBlock:processBlock];
        _audioState.filterPort.clientFormat = self.audioState.asbd;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(connectionsChanged:) name:ABConnectionsChangedNotification object:nil];
    
}

- (void)connectionsChanged:(NSNotification*)notification {
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(stop) object:nil];
    if ( self.audiobusController.connected && !self.running ) {
        // Start the audio system upon connection, if it's not running already
        [self start];
    } else if ( !_audiobusController.connected && self.running
               && [[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground ) {
        // Shut down after 10 seconds if we disconnected while in the background
        [self performSelector:@selector(stop) withObject:nil afterDelay:10.0];
    }
}

@end
