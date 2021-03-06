//
//  MKPresetManagerViewController.m
//
//
//  Created by Mayank Sanganeria on 1/31/15.
//
//

#import "MKPresetManagerViewController.h"
#import "MKPresetManager.h"
#import "MKPresetManagerViewControllerCell.h"
#import <QuartzCore/QuartzCore.h>
#import <STAlertView.h>
#import <iRate.h>
#import <SVProgressHUD.h>

@interface MKPresetManagerViewController () <UICollectionViewDataSource, UICollectionViewDelegate>
@property (weak, nonatomic) IBOutlet UICollectionView *communityPatchesCollectionView;
@property (unsafe_unretained, nonatomic) IBOutlet UICollectionView *myPatchesCollectionView;
@property (strong, nonatomic) NSArray *myPatches;
@property (strong, nonatomic) NSArray *communityPatches;
@property (weak, nonatomic) UICollectionView *selectedCollectionView;
@property (weak, nonatomic) NSIndexPath *selectedIndexPath;
@property (strong, nonatomic) NSDictionary *selectedPreset;
@property (assign, nonatomic) BOOL saveNew;
@property (strong, nonatomic) STAlertView *alertView;
@property (unsafe_unretained, nonatomic) IBOutlet UIButton *nameTextButton;
@property (unsafe_unretained, nonatomic) IBOutlet UIView *tapView;

@end

@implementation MKPresetManagerViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  
//  self.view.backgroundColor = [UIColor colorWithWhite:56/255. alpha:0.8];
  UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doneButtonPressed:)];
  [self.tapView addGestureRecognizer:tap];
  
  if ([[NSUserDefaults standardUserDefaults] objectForKey:@"authorName"]) {
    [self.nameTextButton setTitle:[NSString stringWithFormat:@"%@'s Patches", [[NSUserDefaults standardUserDefaults] objectForKey:@"authorName"]] forState:UIControlStateNormal];
  } else {
    [self nameChanged:nil];
  }
  
  self.communityPatchesCollectionView.delegate = self;
  self.communityPatchesCollectionView.dataSource = self;
  [self.communityPatchesCollectionView registerNib:[UINib nibWithNibName:@"MKPresetManagerViewControllerCell" bundle:nil] forCellWithReuseIdentifier:@"Cell"];
  
  self.myPatchesCollectionView.delegate = self;
  self.myPatchesCollectionView.dataSource = self;
  [self.myPatchesCollectionView registerNib:[UINib nibWithNibName:@"MKPresetManagerViewControllerCell" bundle:nil] forCellWithReuseIdentifier:@"Cell"];
  
  [self.saveButton addTarget:self action:@selector(savePressed) forControlEvents:UIControlEventTouchUpInside];
  [self.deleteButton addTarget:self action:@selector(deletePressed) forControlEvents:UIControlEventTouchUpInside];
  [self.loadButton addTarget:self action:@selector(loadPressed) forControlEvents:UIControlEventTouchUpInside];
  self.saveNew = NO;
  [self refreshPatches];
  [self setButtonsToInitialState];
}

-(void)setButtonsToInitialState
{
  self.deleteButton.alpha = 0.1;
  self.deleteButton.enabled = NO;
  self.saveButton.alpha = 0.1;
  self.saveButton.enabled = NO;
  self.loadButton.alpha = 0.1;
  self.loadButton.enabled = NO;
  self.transferButton.alpha = 0.1;
  self.transferButton.enabled = NO;
}

-(void)refreshPatches
{
  self.myPatches = [MKPresetManager loadAllPresets];
  [self.myPatchesCollectionView reloadData];
  
  [MKPresetManager loadAllPresetsFromCloudWithCompletion:^(NSArray *presets) {
    self.communityPatches = presets;
    [self.communityPatchesCollectionView reloadData];
  }];
}

- (IBAction)doneButtonPressed:(id)sender {
  [UIView animateWithDuration:0.2 animations:^{
    self.view.alpha = 0;
  }];
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  if (collectionView == self.myPatchesCollectionView) {
    return self.myPatches.count + 1;
  }
  if (collectionView == self.communityPatchesCollectionView) {
    return self.communityPatches.count;
  }
  return 0;
}

-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  MKPresetManagerViewControllerCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"Cell" forIndexPath:indexPath];
  cell.layer.masksToBounds = NO;
  cell.layer.shadowColor = [[UIColor whiteColor] CGColor];
  cell.layer.shadowRadius = 5;
  cell.layer.shadowOpacity = 1;
  cell.layer.shadowOffset = CGSizeZero;
  NSDictionary *patch;
  if (collectionView == self.myPatchesCollectionView) {
    if (indexPath.row != 0) {
      patch = self.myPatches[indexPath.row - 1];
    }
  }
  if (collectionView == self.communityPatchesCollectionView) {
    patch = self.communityPatches[indexPath.row];
  }
  cell.patchName.text = patch[@"name"];
  if (![patch objectForKey:@"author"])
    cell.patchAuthor.text = @"";
  else
    cell.patchAuthor.text = [NSString stringWithFormat:@"by %@", patch[@"author"]];
  if (collectionView == self.myPatchesCollectionView) {
    if (indexPath.row == 0) {
      cell.patchName.text = @"Add new...";
      cell.patchAuthor.text = [[NSUserDefaults standardUserDefaults] objectForKey:@"authorName"];
    }
  }
  if (collectionView == self.selectedCollectionView && indexPath == self.selectedIndexPath) {
    cell.backgroundColor = [UIColor colorWithWhite:1.0 alpha:1];
  } else {
    cell.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.5];
  }
  return cell;
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
  self.loadButton.alpha = 1;
  self.loadButton.enabled = YES;
  self.transferButton.alpha = 1;
  self.transferButton.enabled = YES;
  self.selectedIndexPath = indexPath;
  self.selectedCollectionView = collectionView;
  if (collectionView == self.communityPatchesCollectionView) {
    self.deleteButton.alpha = 0.1;
    self.deleteButton.enabled = NO;
    self.saveButton.alpha = 0.1;
    self.saveButton.enabled = NO;
  } else {
    self.deleteButton.alpha = 1;
    self.deleteButton.enabled = YES;
    self.saveButton.alpha = 1;
    self.saveButton.enabled = YES;
  }
  [self.transferButton removeTarget:self action:nil forControlEvents:UIControlEventTouchUpInside];
  if (collectionView == self.myPatchesCollectionView) {
    if (indexPath.row == 0) {
      self.selectedPreset = nil;
      self.saveNew = YES;
      [self savePressed];
    } else {
      self.selectedPreset = self.myPatches[indexPath.row - 1];
      self.saveNew = NO;
    }
    [self.transferButton setTitle:@"UPLOAD" forState:UIControlStateNormal];
    [self.transferButton addTarget:self action:@selector(uploadPatch) forControlEvents:UIControlEventTouchUpInside];
    [self.analytics track:@"Preset Select" properties:@{@"source":@"personal"}];
  }
  if (collectionView == self.communityPatchesCollectionView) {
    self.selectedPreset = self.communityPatches[indexPath.row];
    [self.transferButton setTitle:@"DOWNLOAD" forState:UIControlStateNormal];
    [self.transferButton addTarget:self action:@selector(downloadPatch) forControlEvents:UIControlEventTouchUpInside];
    [self.analytics track:@"Preset Select" properties:@{@"source":@"community"}];
  }
  [self.myPatchesCollectionView reloadData];
  [self.communityPatchesCollectionView reloadData];

}

-(void)savePressed
{
  [self.analytics track:@"Preset Save"];
  if (self.saveNew) {
    self.alertView = [[[STAlertView alloc] initWithTitle:@"Preset Name"
                                                  message:@"Please name your Preset"
                                            textFieldHint:@"Awesome Preset!"
                                           textFieldValue:nil
                                        cancelButtonTitle:@"Cancel"
                                         otherButtonTitle:@"Save"
                        
                                        cancelButtonBlock:^{
                                          
                                        } otherButtonBlock:^(NSString * result){
                                          if (result.length > 0) {
                                            NSMutableDictionary *md = [self.currentPreset mutableCopy];
                                            md[@"name"] = result;
                                            md[@"author"] = [[NSUserDefaults standardUserDefaults] objectForKey:@"authorName"];
                                            self.currentPreset = md;
                                            [MKPresetManager savePreset:self.currentPreset];
                                            [self refreshPatches];
                                            self.selectedCollectionView = nil;
                                            self.selectedIndexPath = nil;
                                            [self setButtonsToInitialState];
                                            [[iRate sharedInstance] logEvent:NO];                                            
                                          }
                                        }] show];
  } else {
    NSMutableDictionary *md = [self.currentPreset mutableCopy];
    md[@"name"] = self.selectedPreset[@"name"];
    md[@"author"] = [[NSUserDefaults standardUserDefaults] objectForKey:@"authorName"];
    [MKPresetManager savePreset:md];
    [self refreshPatches];
  }
}

-(void)loadPressed
{
  [self.analytics track:@"Preset Load"];
  NSDictionary *preset = self.selectedPreset;
  if ([self.delegate respondsToSelector:@selector(loadPreset:)]) {
    [self.delegate loadPreset:preset];
  }
}

-(void)deletePressed
{
  [self.analytics track:@"Preset delete"];
  [MKPresetManager deletePresetWithName:self.selectedPreset[@"name"]];
  self.selectedPreset = nil;
  self.selectedCollectionView = nil;
  self.selectedIndexPath = nil;
  [self setButtonsToInitialState];
  [self refreshPatches];
}

-(void)downloadPatch
{
  [self.analytics track:@"Preset Download"];
  [MKPresetManager savePreset:self.selectedPreset];
  [self refreshPatches];
  [SVProgressHUD showSuccessWithStatus:@"Saved!"];
}

-(void)uploadPatch
{
  [self.analytics track:@"Preset Upload"];
  NSDictionary *preset = self.selectedPreset;
  [SVProgressHUD showWithStatus:@"Uploading..."];
  [MKPresetManager saveToCloudPreset:preset withCompletion:^{
    dispatch_async(dispatch_get_main_queue(), ^{
      [self refreshPatches];
      [SVProgressHUD showSuccessWithStatus:@"Uploaded!"];
    });
  }];
}

-(BOOL)updateAuthorName:(NSString *)name
{
  if (name && name.length > 0) {
    [[NSUserDefaults standardUserDefaults] setObject:name forKey:@"authorName"];
    [self.nameTextButton setTitle:[NSString stringWithFormat:@"%@'s Patches", [[NSUserDefaults standardUserDefaults] objectForKey:@"authorName"]] forState:UIControlStateNormal];
    [self.myPatchesCollectionView reloadData];
    return YES;
  }
  return NO;
}

- (IBAction)nameChanged:(id)sender {
  self.alertView = [[[STAlertView alloc] initWithTitle:@"Author Name"
                                               message:@"Please enter your name!"
                                         textFieldHint:@"Name"
                                        textFieldValue:nil
                                     cancelButtonTitle:@"Cancel"
                                      otherButtonTitle:@"Done"
                                     cancelButtonBlock:^{
                                         [self nameChanged:nil];
                                     } otherButtonBlock:^(NSString * result){
                                       if (![self updateAuthorName:result]) {
                                         [self nameChanged:nil];
                                       }
                                     }] show];
}

@end
