//
//  MKPresetManager.m
//  grainproc
//
//  Created by Mayank on 7/14/15.
//  Copyright (c) 2015 Mayank, Kurt. All rights reserved.
//

#import "MKPresetManager.h"
#import <Parse.h>
#import <Firebase/Firebase.h>

@implementation MKPresetManager

+(void)savePreset:(NSDictionary *)preset
{
  NSMutableDictionary *presets = [[NSUserDefaults standardUserDefaults] valueForKey:@"presets"];
  if (!presets) {
    presets = [NSMutableDictionary dictionary];
  } else {
    presets = [presets mutableCopy];
  }
//  if (!preset.author && !preset.author.length)
//    preset.author = [[NSUserDefaults standardUserDefaults] objectForKey:@"authorName"];
//  if (![preset objectForKey:@"author"]) {
    NSMutableDictionary *md = [preset mutableCopy];
//    md[@"author"] = @"e7mac";//[[NSUserDefaults standardUserDefaults] objectForKey:@"authorName"];
    preset = md;
//  }
  [presets setValue:preset forKey:preset[@"name"]];
  [[NSUserDefaults standardUserDefaults] setValue:presets forKey:@"presets"];
}

+(void)savePresets:(NSArray *)presets
{
  NSMutableDictionary *newPresets = [[[NSUserDefaults standardUserDefaults] valueForKey:@"presets"] mutableCopy];
  if (!presets) {
    presets = @[];
  }
  for (NSDictionary *preset in presets) {
    [newPresets setValue:preset forKey:preset[@"name"]];
  }
  [[NSUserDefaults standardUserDefaults] setValue:newPresets forKey:@"presets"];
}

+(NSDictionary *)loadPresetWithName:(NSString *)presetName
{
  NSDictionary *presetDict = [[NSUserDefaults standardUserDefaults] valueForKey:@"presets"][presetName];
  return presetDict;
}

+(NSArray *)loadAllPresets
{
  NSDictionary *presetDicts = [[NSUserDefaults standardUserDefaults] valueForKey:@"presets"];
  NSMutableArray *presets = [NSMutableArray array];
  for (NSString *key in presetDicts) {
    [presets addObject:presetDicts[key]];
  }
  return presets;
}

+(BOOL)deletePresetWithName:(NSString *)presetName
{
  NSMutableDictionary *presetDicts = [[[NSUserDefaults standardUserDefaults] valueForKey:@"presets"] mutableCopy];
  if (![presetDicts objectForKey:presetName]) {
    return 0;
  }
  [presetDicts removeObjectForKey:presetName];
  [[NSUserDefaults standardUserDefaults] setObject:presetDicts forKey:@"presets"];
  return 1;
}

#pragma mark Parse methods

+(void)saveToCloudPreset:(NSDictionary *)preset withCompletion:(void (^)())completion
{
  NSArray *presets = [[NSUserDefaults standardUserDefaults] valueForKey:@"presets"];
  FIRDatabaseReference *db = [[FIRDatabase database] referenceWithPath:@"presets"];
  [[db childByAutoId] setValue:preset];
  if (completion) {
    completion();
  }
}

+(void)loadAllPresetsFromCloudWithCompletion:(void (^)(NSArray *presets))completion;
{
  FIRDatabaseReference *db = [[FIRDatabase database] referenceWithPath:@"presets"];
  
  [db observeEventType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot * _Nonnull snapshot) {
    NSArray *objects = [snapshot.value allValues];
    if (completion) {
      completion(objects);
    }
  }];
}


@end
