//
//  MainViewController.h
//  imgFinder
//
//  Created by LuDong on 2018/8/28.
//  Copyright © 2018年 LuDong. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <opencv2/videoio/cap_ios.h>
#include <opencv2/features2d.hpp>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/calib3d.hpp>
#include <vector>
#include <map>
#include <unordered_map>
using namespace std;
using namespace cv;

@interface MainViewController : UIViewController<AVCaptureVideoDataOutputSampleBufferDelegate, CvVideoCameraDelegate> {
    
    __weak IBOutlet UILabel *showLabel;
    __weak IBOutlet UIImageView *previewImageView;
    CvVideoCamera* videoCamera;
    flann::Index *flann_index;
    
    BOOL enable;
    vector<KeyPoint> kpts;
    Mat desc;
    
    Mat totalDescs;
    int vec[100000];
    int index;
    
    int topK[100000];
    int idx;
    int galVec[100000];
    int globalCount;
    double start_time;
    NSURLSession *sess;
    
    AVCaptureVideoDataOutput *output;
    AVCaptureSession     *session;
    AVCaptureDeviceInput *inputDevice;
    
    uint8_t *planerData;
    
    NSLock *theLock;
    NSMutableArray *mArr;
    Mat tmpFrame;
    NSArray *fileArr;
    int tick;
}
- (IBAction)uploadAction:(id)sender;
    
@end
