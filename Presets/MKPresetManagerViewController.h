//
//  MKPresetManagerViewController.h
//  
//
//  Created by Mayank Sanganeria on 1/31/15.
//
//

#import <UIKit/UIKit.h>

@protocol MKPresetManagerViewControllerDelegate <NSObject>

-(void)loadPreset:(NSDictionary *)preset;

@end

@interface MKPresetManagerViewController : UIViewController

@property (weak, nonatomic) IBOutlet UIButton *loadButton;
@property (weak, nonatomic) IBOutlet UIButton *saveButton;
@property (weak, nonatomic) IBOutlet UIButton *deleteButton;
@property (weak, nonatomic) IBOutlet UIButton *transferButton;

@property (strong, nonatomic) NSDictionary *currentPreset;

@property (weak, nonatomic) id<MKPresetManagerViewControllerDelegate> delegate;

-(void)refreshPatches;

@end
