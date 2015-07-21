//
//  MKMIDIManager.m
//  Pods
//
//  Created by Mayank on 7/21/15.
//
//

#import "MKMIDIManager.h"
#import <MIKMIDI.h>

@implementation MKMIDIManager

static MKMIDIManager *sharedInstance;

+ (instancetype)sharedInstance
{
  if (sharedInstance == nil) {
    sharedInstance = [[MKMIDIManager alloc] init];
  }
  return sharedInstance;
}

-(instancetype)init
{
  self = [super init];
  if (self) {
    [self refreshMIDIConnections];
  }
  return self;
}

-(void)refreshMIDIConnections
{
  for (MIKMIDIDevice *device in [[MIKMIDIDeviceManager sharedDeviceManager] availableDevices]) {
    NSArray *sources = [device.entities valueForKeyPath:@"@unionOfArrays.sources"];
    MIKMIDISourceEndpoint *source = [sources firstObject]; // Or whichever source you want, but often there's only one.
    
    MIKMIDIDeviceManager *manager = [MIKMIDIDeviceManager sharedDeviceManager];
    
    NSError *error = nil;
    
    BOOL success = [manager connectInput:source error:&error eventHandler:^(MIKMIDISourceEndpoint *source, NSArray *commands) {
      for (MIKMIDICommand *command in commands) {
        switch (command.commandType) {
          case MIKMIDICommandTypeNoteOn: {
            MIKMIDINoteOnCommand *noteOnCommand = (MIKMIDINoteOnCommand *)command;
            if (noteOnCommand.velocity > 0) {
              [[NSNotificationCenter defaultCenter] postNotificationName:MKMIDIManagerNoteOnKey
                                                                  object:@{
                                                                           @"note":@(noteOnCommand.note),
                                                                           @"velocity":
                                                                             @(noteOnCommand.velocity)}];
            } else {
              [[NSNotificationCenter defaultCenter] postNotificationName:MKMIDIManagerNoteOffKey
                                                                  object:@{@"note":@(noteOnCommand.note),
                                                                           @"velocity":
                                                                             @(noteOnCommand.velocity)}];
            }
          }
            break;
          default:
            break;
        }
      }
    }];
    if (!success) {
      //      [[[UIAlertView alloc] initWithTitle:@"error" message:[error description] delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Ok", nil] show];
    }
  }
}

@end
