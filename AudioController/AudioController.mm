//
//  AudioController.m
//  GrainProc
//
//  Created by Kurt Werner on 9/22/13.
//  Copyright (c) 2013 Mayank, Kurt. All rights reserved.
//

#import "AudioController.h"
static void * kAudiobusRunningOrConnectedChanged = &kAudiobusRunningOrConnectedChanged;

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
      NSError *error = nil;
      if ( ![[AVAudioSession sharedInstance] setActive:YES error:&error]) {
        NSLog(@"Couldn't set audio session active: %@", error);
      }

      CheckError (AudioOutputUnitStart (audioController.audioState.rioUnit),
                  "Couldn't start RIO unit");
      NSString *category = AVAudioSessionCategoryPlayAndRecord;
      AVAudioSessionCategoryOptions options = AVAudioSessionCategoryOptionMixWithOthers;
      if ( ![[AVAudioSession sharedInstance] setCategory:category withOptions:options error:&error] ) {
        NSLog(@"Couldn't set audio session category: %@", error);
      }
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
  BOOL success;
  NSError *error;
  //headphones taken out
  if (routeChangeReason ==
      kAudioSessionRouteChangeReason_OldDeviceUnavailable) {  // 9
    success = [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker
                                         error:&error];
    if (!success)  NSLog(@"AVAudioSession error overrideOutputAudioPort:%@",error);
  }
  //headphones plugged
  if (routeChangeReason ==
      kAudioSessionRouteChangeReason_NewDeviceAvailable) {  // 9
    success = [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone
                                                                 error:&error];
    if (!success)  NSLog(@"AVAudioSession error overrideOutputAudioPort:%@",error);
  }
  NSString *category = AVAudioSessionCategoryPlayAndRecord;
  AVAudioSessionCategoryOptions options = AVAudioSessionCategoryOptionMixWithOthers;
  if ( ![[AVAudioSession sharedInstance] setCategory:category withOptions:options error:&error] ) {
    NSLog(@"Couldn't set audio session category: %@", error);
  }
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
    // Watch the audiobusAppRunning and connected properties
    [_audiobusController addObserver:self
                          forKeyPath:@"connected"
                             options:0
                             context:kAudiobusRunningOrConnectedChanged];
    [_audiobusController addObserver:self
                          forKeyPath:@"audiobusAppRunning"
                             options:0
                             context:kAudiobusRunningOrConnectedChanged];
  }
  return self;
}

-(void)observeValueForKeyPath:(NSString *)keyPath
                     ofObject:(id)object
                       change:(NSDictionary *)change
                      context:(void *)context {
  if ( context == kAudiobusRunningOrConnectedChanged ) {
    if ( [UIApplication sharedApplication].applicationState == UIApplicationStateBackground
        && !_audiobusController.connected
        && !_audiobusController.audiobusAppRunning ) {
      // Audiobus has quit. Time to sleep.
      [self stop];
    }
  } else {
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
  }
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
  AVAudioSession *session = [AVAudioSession sharedInstance];
  //error handling
  BOOL success;
  NSError* error;
  
  //set the audioSession category.
  //Needs to be Record or PlayAndRecord to use audioRouteOverride:
  
  NSString *category = AVAudioSessionCategoryPlayAndRecord;
  AVAudioSessionCategoryOptions options = AVAudioSessionCategoryOptionMixWithOthers;
  if ( ![[AVAudioSession sharedInstance] setCategory:category withOptions:options error:&error] ) {
    NSLog(@"Couldn't set audio session category: %@", error);
  }
  if ([[UIDevice currentDevice].model isEqualToString:@"iPhone"])
  {
    //set the audioSession override
    success = [session overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker
                                         error:&error];
    if (!success)  NSLog(@"AVAudioSession error overrideOutputAudioPort:%@",error);
    
    
    AudioSessionPropertyID routeChangeID =
    kAudioSessionProperty_AudioRouteChange;    // 1
    AudioSessionAddPropertyListener (                                  // 2
                                     routeChangeID,                                                 // 3
                                     audioRouteChangeListenerCallback,                                      // 4
                                     nil                                                       // 5
                                     );
    
    
  }
  
  Float32 preferredBufferDuration = 0.01;
  success = [session setPreferredIOBufferDuration:preferredBufferDuration error:&error];
  if (!success)  NSLog(@"AVAudioSession error set buffer duration:%@",error);

  
  Float64 requestSampleRateStoredInVariable = (Float64)requestedSampleRate;
  success = [session setPreferredSampleRate:requestSampleRateStoredInVariable error:&error];
  if (!success)  NSLog(@"AVAudioSession error set buffer duration:%@",error);
  
  _hardwareSampleRate = session.sampleRate;
  NSLog (@"hardwareSampleRate = %f", _hardwareSampleRate);
  
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
-(void)setupAudiobusWithKey:(NSString *)apiKey withOutputPort:(NSDictionary *)outputDescription outputPortDescription:(AudioComponentDescription)outputPortDescription filterPort:(NSDictionary *)filterDescription filterPortDescription:(AudioComponentDescription)filterPortDescription
{
  self.audiobusController = [[ABAudiobusController alloc]
                             initWithApiKey:apiKey];
  if (outputDescription) {
    //add sender port
    _audioState.audiobusOutputPort = [[ABSenderPort alloc] initWithName:outputDescription[@"name"]
                                                                  title:outputDescription[@"title"]
                                              audioComponentDescription:outputPortDescription
                                                              audioUnit:_audioState.rioUnit];
    [_audiobusController addSenderPort:_audioState.audiobusOutputPort];
    //    _audioState.audiobusOutputPort = [[ABSenderPort alloc] initWithName:@"grainproc"
    //                                                                  title:NSLocalizedString(@"Main App Output", @"")
    //                                              audioComponentDescription:(AudioComponentDescription) {
    //                                                .componentType = kAudioUnitType_RemoteGenerator,
    //                                                .componentSubType = 'gprg', // Note single quotes
    //                                                .componentManufacturer = 'emac' }
    //                                                              audioUnit:_audioState.rioUnit];
    //    [_audiobusController addSenderPort:_audioState.audiobusOutputPort];
  }
  if (filterDescription) {
    // In app initialisation...
    _audioState.filterPort = [[ABFilterPort alloc] initWithName:filterDescription[@"name"]
                                                          title:filterDescription[@"title"]
                                      audioComponentDescription:filterPortDescription
                                                      audioUnit:_audioState.rioUnit];
    //      _audioState.filterPort = [[ABFilterPort alloc] initWithName:@"grainproc.filter"
    //                                                            title:@"Granular effect"
    //                                        audioComponentDescription:(AudioComponentDescription) {
    //                                          .componentType = kAudioUnitType_RemoteEffect,
    //                                          .componentSubType = 'gprx',
    //                                          .componentManufacturer = 'emac' }
    //                                                        audioUnit:_audioState.rioUnit];
    [_audiobusController addFilterPort:_audioState.filterPort];
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
