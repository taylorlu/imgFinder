//
//  ViewController.h
//  imgFinder
//
//  Created by LuDong on 2018/8/22.
//  Copyright © 2018年 LuDong. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <opencv2/videoio/cap_ios.h>
#include <opencv2/features2d.hpp>
#include "rbslsh.h"

using namespace std;
using namespace cv;

@interface ViewController : UIViewController<CvVideoCameraDelegate> {
    
    __weak IBOutlet UIImageView *previewImageView;
    CvVideoCamera* videoCamera;
    
    BOOL enable;
    vector<KeyPoint> kpts;
    Mat desc;
    int L;
    int N;
    lshbox::rbsLsh mylsh;
    lshbox::rbsLsh myminilsh;
}

-(void) initLSH;

@end
