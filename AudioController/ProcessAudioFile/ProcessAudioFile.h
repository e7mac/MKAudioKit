// includes
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

// helpers
#include "CAXException.h"
#include "CAStreamBasicDescription.h"

@interface ProcessAudioFile : NSObject

-(void)convertSource:(NSURL *)source destination:(NSURL *)destination  filterBlock:(void (^)(AudioSampleType &sample))filterBlock;

@end