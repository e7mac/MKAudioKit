//
//  MKMIDIManager.h
//  Pods
//
//  Created by Mayank on 7/21/15.
//
//

#import <Foundation/Foundation.h>

static NSString *MKMIDIManagerNoteOnKey = @"MKMIDIManagerNoteOnKey";
static NSString *MKMIDIManagerNoteOffKey = @"MKMIDIManagerNoteOffKey";

@interface MKMIDIManager : NSObject

+ (instancetype)sharedInstance;

@end
