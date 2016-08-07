//
//  MKPresetManagerViewController.h
//  
//
//  Created by Mayank Sanganeria on 1/31/15.
//
//

#import <UIKit/UIKit.h>
#import <MSAnalytics.h>

@protocol MKPresetManagerViewControllerDelegate <NSObject>

-(void)loadPreset:(NSDictionary *)preset;

@end

@interface MKPresetManagerViewController : UIViewController
@property (unsafe_unretained, nonatomic) IBOutlet UIButton *loadButton;
@property (unsafe_unretained, nonatomic) IBOutlet UIButton *saveButton;
@property (unsafe_unretained, nonatomic) IBOutlet UIButton *deleteButton;
@property (unsafe_unretained, nonatomic) IBOutlet UIButton *transferButton;

@property (strong, nonatomic) NSDictionary *currentPreset;
@property (weak, nonatomic) id<MSAnalytics> analytics;

@property (weak, nonatomic) id<MKPresetManagerViewControllerDelegate> delegate;

-(void)refreshPatches;

@end
