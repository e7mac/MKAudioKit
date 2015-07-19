//
//  MKPresetManager.h
//  grainproc
//
//  Created by Mayank on 7/14/15.
//  Copyright (c) 2015 Mayank, Kurt. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MKPresetManager : NSObject

+(void)savePreset:(NSDictionary *)preset;
+(void)savePresets:(NSArray *)presets;
+(NSDictionary *)loadPresetWithName:(NSString *)presetName;
+(BOOL)deletePresetWithName:(NSString *)presetName;
+(NSArray *)loadAllPresets;

+(void)saveToCloudPreset:(NSDictionary *)preset withCompletion:(void (^)())completion;
+(void)loadAllPresetsFromCloudWithCompletion:(void (^)(NSArray *presets))completion;

@end
