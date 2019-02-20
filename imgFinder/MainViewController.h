//
//  MainViewController.h
//  imgFinder
//
//  Created by LuDong on 2018/8/28.
//  Copyright © 2018年 LuDong. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RetrieveObject.h"

@interface MainViewController : UIViewController<RetrieveDelegate> {
    
    __weak IBOutlet UILabel *showLabel;
    __weak IBOutlet UIImageView *previewImageView;
    RetrieveObject *retrieveObject;
    
    bool isCapture;
}
- (IBAction)clickAction:(id)sender;

@end
