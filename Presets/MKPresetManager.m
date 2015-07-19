//
//  MKPresetManager.m
//  grainproc
//
//  Created by Mayank on 7/14/15.
//  Copyright (c) 2015 Mayank, Kurt. All rights reserved.
//

#import "MKPresetManager.h"
#import <Parse.h>

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
  PFObject *testObject = [PFObject objectWithClassName:@"GrainProcPreset"];
  NSDictionary *d = preset;
  for (NSString *key in d.allKeys) {
    NSString *value = d[key];
    [testObject setObject:value forKey:key];
  }
  [testObject saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
    if (succeeded) {
      NSLog(@"yes");
      if (completion) {
        completion();
      }
    } else {
      NSLog([error description]);
    }
  }];
}

+(void)loadAllPresetsFromCloudWithCompletion:(void (^)(NSArray *presets))completion;
{
  PFQuery *q = [PFQuery queryWithClassName:@"GrainProcPreset"];
  [q findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
    NSMutableArray *ds = [@[] mutableCopy];
    for (PFObject *object in objects) {
      NSMutableDictionary *d = [@{} mutableCopy];
      for (NSString *key in object.allKeys) {
        d[key] = object[key];
      }
      [ds addObject:d];
    }
    NSMutableArray *presets = [@[] mutableCopy];
    for (NSDictionary *d in ds) {
      NSDictionary *preset = d;
      [presets addObject:preset];
    }
    if (completion) {
      completion(presets);
    }
  }];
}


@end
