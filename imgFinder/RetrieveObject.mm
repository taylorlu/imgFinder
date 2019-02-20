//
//  RetrieveObject.m
//  imgFinder
//
//  Created by LuDong on 2018/12/21.
//  Copyright © 2018年 LuDong. All rights reserved.
//

#import "RetrieveObject.h"

using namespace std;
using namespace cv;

@implementation RetrieveObject

- (NSString *)md5:(NSString *)string{
    const char *cStr = [string UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    
    CC_MD5(cStr, (CC_LONG)strlen(cStr), digest);
    
    NSMutableString *result = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [result appendFormat:@"%02X", digest[i]];
    }
    
    return result;
}

- (NSString *)currentDateStr{
    NSDate *currentDate = [NSDate date];//获取当前时间，日期
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];// 创建一个时间格式化对象
    [dateFormatter setDateFormat:@"YYYYMMddhhmmss"];//设定时间格式,这里可以设置成自己需要的格式
    NSString *dateString = [dateFormatter stringFromDate:currentDate];//将时间转化成字符串
    return dateString;
}

- (void)processImage:(Mat&)image {
    
    if([theLock tryLock]) {
        tmpFrame = image.clone();
        [theLock unlock];
    }
}

-(void)sendRequest:(vector<KeyPoint> &)kpts :(Mat &) desc {
    
    NSMutableData *data = [[NSMutableData alloc] init];
    unsigned short pointCount = (unsigned short)kpts.size();
    [data appendBytes:(void*)&pointCount length:sizeof(unsigned short)];
    for (int i=0;i<kpts.size(); i++) {
        unordered_map<int, int> matchMaps;
        uchar *lineData = (uchar *)(desc.data + i*desc.step[0]);
        vector<uint32_t> hashvals;
        flann_index->getHashVal(lineData, hashvals);
        
        for(int k=0; k<hashvals.size(); k++) {
            [data appendBytes:(void*)&hashvals[k] length:sizeof(uint32_t)];
        }
        unsigned short ptx = (unsigned short)kpts[i].pt.x;
        [data appendBytes:(void*)&ptx length:sizeof(unsigned short)];
        unsigned short pty = (unsigned short)kpts[i].pt.y;
        [data appendBytes:(void*)&pty length:sizeof(unsigned short)];
    }
    NSString *encryptionKey = @"20171222181418uo1l3nyqgjqudni102";
    NSString *sourceCode = @"cms";
    NSString *time = [self currentDateStr];
    NSString *sign = [self md5:[NSString stringWithFormat:@"%d%@%@", pointCount, encryptionKey, time]];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@?sourceCode=%@&sign=%@&time=%@", retrieveURL, sourceCode, sign, time]];
    
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    NSString *contentType = [NSString stringWithFormat:@"application/octet-stream"];
    [request setValue:contentType forHTTPHeaderField: @"Content-Type"];
    NSString *encodeType = [NSString stringWithFormat:@"charset"];
    [request setValue:encodeType forHTTPHeaderField:@"UTF-8"];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    [request setHTTPBody:data];
    NSString *postLength = [NSString stringWithFormat:@"%lu", [data length]];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    sess = [NSURLSession sessionWithConfiguration:configuration];
    
    NSURLSessionDataTask *uploadtask = [sess dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        if(data!=nil) {
            NSDictionary *jsonDic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
            int code = [[jsonDic objectForKey:@"code"] intValue];
            if(code==0) {
                NSDictionary *infoDic = [jsonDic objectForKey:@"info"];
                NSString *cidStr = [infoDic objectForKey:@"cid"];
                [[self retrieveDelegate] retrieveCallback:cidStr];
//                dispatch_async(dispatch_queue_create(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
//                    [self doRetrieve];
//                });
            }
            else {
                [[self retrieveDelegate] retrieveCallback:[NSString stringWithFormat:@"%d", code]];
                dispatch_async(dispatch_queue_create(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    [self doRetrieve];
                });
            }
        }
        else {
            dispatch_async(dispatch_queue_create(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self doRetrieve];
            });
        }
    }];
    [uploadtask resume];
}

-(void)doRetrieve {

    [theLock lock];
    if(tmpFrame.empty()) {
        [theLock unlock];
        dispatch_async(dispatch_queue_create(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self doRetrieve];
        });
        return;
    }
    Mat imageGrey;
    cvtColor(tmpFrame, imageGrey, CV_RGB2GRAY);
    Mat imageSobel;
    Laplacian(imageGrey, imageSobel, CV_8U);    //filter the blur frame
    double meanValue = mean(imageSobel)[0];
    if(meanValue<2) {
        tmpFrame.release();
        [theLock unlock];
        dispatch_async(dispatch_queue_create(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self doRetrieve];
        });
        return;
    }

    Ptr<AKAZE> akaze = AKAZE::create();
    akaze->setThreshold(0.002);
    vector<KeyPoint> kpts;
    Mat desc;
    akaze->detectAndCompute(tmpFrame, noArray(), kpts, desc);
    tmpFrame.release();
    [theLock unlock];
    if(kpts.size()<100) {   //image is too flatten
        dispatch_async(dispatch_queue_create(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self doRetrieve];
        });
        return;
    }
    [self sendRequest:kpts :desc];
}

- (void)initRetrieve:(NSString *)url :(UIImageView *)previewImageView {
    theLock = [[NSLock alloc] init];
    
    retrieveURL = url;
    sess = [NSURLSession sharedSession];
    
    NSString *lshpath = [[NSBundle mainBundle] pathForResource:@"BASIC_Hash" ofType:@"dat"];
    flann_index = new flann::Index(Mat(cv::Size(61, 1), CV_8U), flann::SavedIndexParams([lshpath UTF8String]), cvflann::FLANN_DIST_HAMMING);
    
    videoCamera = [[CvVideoCamera alloc] initWithParentView:previewImageView];
    [videoCamera setDefaultAVCaptureDevicePosition:AVCaptureDevicePositionBack];
    [videoCamera setDefaultAVCaptureSessionPreset:AVCaptureSessionPreset640x480];
    [videoCamera setDefaultAVCaptureVideoOrientation:AVCaptureVideoOrientationPortrait];
    [videoCamera setDelegate:self];
}

- (void)startRetrieve {
    
    [videoCamera start];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self doRetrieve];
    });
}

- (void)stopRetrieve {
    [videoCamera stop];
}

-(void)initPostImage:(NSString *)url {
    
    retrieveURL = url;
    sess = [NSURLSession sharedSession];
    
    NSString *lshpath = [[NSBundle mainBundle] pathForResource:@"BASIC_Hash" ofType:@"dat"];
    flann_index = new flann::Index(Mat(cv::Size(61, 1), CV_8U), flann::SavedIndexParams([lshpath UTF8String]), cvflann::FLANN_DIST_HAMMING);
}

-(int)postUIImage:(UIImage *)image {
    
    Mat cvImage;
    UIImageToMat(image, cvImage);
    
    if(!cvImage.empty()){
        Mat imageGrey;
        cvtColor(cvImage, imageGrey, CV_RGB2GRAY);
        
        Mat imageSobel;
        Laplacian(imageGrey, imageSobel, CV_8U);    //filter the blur frame
        double meanValue = mean(imageSobel)[0];
        if(meanValue<2) {
            return -1;
        }
        
        Ptr<AKAZE> akaze = AKAZE::create();
        akaze->setThreshold(0.002);
        vector<KeyPoint> kpts;
        Mat desc;
        akaze->detectAndCompute(cvImage, noArray(), kpts, desc);
        if(kpts.size()<100) {   //image is too flatten
            return -1;
        }
        [self sendRequest:kpts :desc];
        return 0;
    }
    return -1;
}

@end
