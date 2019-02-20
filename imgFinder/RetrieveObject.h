//
//  RetrieveObject.h
//  imgFinder
//
//  Created by LuDong on 2018/12/21.
//  Copyright © 2018年 LuDong. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <opencv2/videoio/cap_ios.h>
#include <opencv2/features2d.hpp>
#include <opencv2/imgcodecs.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/calib3d.hpp>
#include <opencv2/imgcodecs/ios.h>
#include <vector>
#include <map>
#include <unordered_map>
#import <CommonCrypto/CommonDigest.h>

using namespace std;
using namespace cv;

#define FIX_SIZE 640

@protocol RetrieveDelegate <NSObject>
- (void)retrieveCallback:(NSString *)cid;
@end

@interface RetrieveObject : NSObject<CvVideoCameraDelegate> {
    
    CvVideoCamera* videoCamera;
    flann::Index *flann_index;
    
    NSURLSession *sess;
    NSString *retrieveURL;
    
    NSLock *theLock;
    Mat tmpFrame;
}

- (void)initRetrieve:(NSString *)url :(UIImageView *)previewImageView;
- (void)startRetrieve;
- (void)stopRetrieve;

-(void)initPostImage:(NSString *)url;
-(int)postUIImage:(UIImage *)image;

@property (weak, nonatomic) id<RetrieveDelegate> retrieveDelegate;

@end
