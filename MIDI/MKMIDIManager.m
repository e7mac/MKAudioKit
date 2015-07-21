//
//  MKMIDIManager.m
//  Pods
//
//  Created by Mayank on 7/21/15.
//
//

#import "MKMIDIManager.h"
#import <MIKMIDI.h>

@interface MKMIDIManager()

@property (strong, nonatomic) NSArray *connectionTokens;
@property (strong, nonatomic) NSArray *connections;

@end

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
    [[MIKMIDIDeviceManager sharedDeviceManager] addObserver:self forKeyPath:@"availableDevices" options:NSKeyValueObservingOptionNew context:nil];
  }
  return self;
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
  if (object == [MIKMIDIDeviceManager sharedDeviceManager]) {
    [self removeAllMIDIConnections];
    [self refreshMIDIConnections];
  }
}

-(void)removeAllMIDIConnections
{
  NSArray *connectionTokens = self.connectionTokens;
  NSArray *connections = self.connections;
  for (int i=0;i<connections.count;i++) {
    MIKMIDIDeviceManager *manager = [MIKMIDIDeviceManager sharedDeviceManager];
    [manager disconnectInput:connections[i] forConnectionToken:connectionTokens[i]];
  }
  self.connections = @[];
  self.connectionTokens = @[];
}

-(void)refreshMIDIConnections
{
  NSMutableArray *connectionTokens = [@[] mutableCopy];
  NSMutableArray *connections = [@[] mutableCopy];
  for (MIKMIDIDevice *device in [[MIKMIDIDeviceManager sharedDeviceManager] availableDevices]) {
    NSArray *sources = [device.entities valueForKeyPath:@"@unionOfArrays.sources"];
    MIKMIDISourceEndpoint *source = [sources firstObject]; // Or whichever source you want, but often there's only one.
    
    MIKMIDIDeviceManager *manager = [MIKMIDIDeviceManager sharedDeviceManager];
    
    NSError *error = nil;
    
    id token = [manager connectInput:source error:&error eventHandler:^(MIKMIDISourceEndpoint *source, NSArray *commands) {
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
    if (token) {
      [connectionTokens addObject:token];
      [connections addObject:source];
    } else {
      //error connecting
    }
  }
  self.connectionTokens = connectionTokens;
  self.connections = connections;
}

@end
