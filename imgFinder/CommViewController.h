//
//  CommViewController.h
//  imgFinder
//
//  Created by LuDong on 2018/8/9.
//  Copyright © 2018年 LuDong. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <opencv2/videoio/cap_ios.h>
#include <opencv2/features2d.hpp>
#include "rbslsh.h"

using namespace std;
using namespace cv;

//#import <opencv2/highgui/cap_ios.h>
//#include <opencv2/features2d/features2d.hpp>
//#include <opencv2/nonfree/features2d.hpp>

@interface CommViewController : UIViewController<CvVideoCameraDelegate> {
    
    CvVideoCamera* videoCamera;
    IBOutlet UIImageView *previewImageView;

    __weak IBOutlet UILabel *label;
    
    BOOL enable;
    vector<KeyPoint> kpts;
    Mat desc;
    int L;
    int N;
    lshbox::rbsLsh mylsh;
}
- (IBAction)subaction:(id)sender;

- (IBAction)click:(id)sender;
@end
