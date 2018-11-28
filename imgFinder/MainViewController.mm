//
//  MainViewController.m
//  imgFinder
//
//  Created by LuDong on 2018/8/28.
//  Copyright © 2018年 LuDong. All rights reserved.
//

#import "MainViewController.h"
#import <CommonCrypto/CommonDigest.h>

#define FIX_SIZE 640

using namespace std;
using namespace cv;

@interface MainViewController ()

@end

@implementation MainViewController

class timer
{
public:
    timer(): time(double(clock())) {};
    ~timer() {};
    /**
     * Restart the timer.
     */
    void restart()
    {
        time = double(clock());
    }
    /**
     * Measures elapsed time.
     *
     * @return The elapsed time
     */
    double elapsed()
    {
        return (double(clock()) - time) / CLOCKS_PER_SEC;
    }
private:
    double time;
};

bool comp_by_value_int(pair<int,int> &p1, pair<int,int> &p2){
    return p1.second > p2.second;
}

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

-(void)sendRequest {
    
    [theLock lock];
    if(tmpFrame.empty()) {
        [theLock unlock];
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
        return;
    }
    
    Ptr<AKAZE> akaze = AKAZE::create();
    akaze->setThreshold(0.002);
    akaze->detectAndCompute(tmpFrame, noArray(), kpts, desc);
    tmpFrame.release();
    [theLock unlock];
    if(kpts.size()<100) {   //image is too flatten
        return;
    }
    
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
    
    //    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://10.102.25.19:9011/arImageHandle/search?sourceCode=%@&pointCount=%d&sign=%@&time=%@", sourceCode, pointCount, sign, time]];
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://192.168.179.119:9011/arImageHandle/search?sourceCode=%@&sign=%@&time=%@", sourceCode, sign, time]];
    
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    NSString *contentType = [NSString stringWithFormat:@"application/octet-stream"];
    [request setValue:contentType forHTTPHeaderField: @"Content-Type"];
    NSString *encodeType = [NSString stringWithFormat:@"charset"];
    [request setValue:encodeType forHTTPHeaderField:@"UTF-8"];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    [request setTimeoutInterval:20];
    [request setHTTPBody:data];
    NSString *postLength = [NSString stringWithFormat:@"%lu", [data length]];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];
    
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
    sess = [NSURLSession sessionWithConfiguration:configuration];

    double curtime = CACurrentMediaTime();
    
    NSURLSessionDataTask *uploadtask = [sess dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        if(data!=nil) {
            double timecost = CACurrentMediaTime()-curtime;
            
            NSLog(@"tick = %d, time = %lf, %@", tick, timecost, [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
            tick++;
            NSDictionary *jsonDic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableLeaves error:&error];
            int code = [[jsonDic objectForKey:@"code"] intValue];

            dispatch_async(dispatch_get_main_queue(), ^{
                if(code==0) {
                    NSDictionary *infoDic = [jsonDic objectForKey:@"info"];
                    [showLabel setText:[infoDic objectForKey:@"cid"]];
                }
                else {
                    [showLabel setText:@""];
                }
            });
        }
    }];
    [uploadtask resume];
}

- (void)processImage:(Mat&)image {

    if([theLock tryLock]) {
        tmpFrame = image.clone();
        [theLock unlock];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    mArr = [[NSMutableArray alloc] init];
    theLock = [[NSLock alloc] init];
    
    index = 0;
    globalCount = 0;
    start_time = CACurrentMediaTime();
    sess = [NSURLSession sharedSession];

    NSString *lshpath = [[NSBundle mainBundle] pathForResource:@"BASIC_Hash" ofType:@"dat"];
    flann_index = new flann::Index(Mat(cv::Size(61, 1), CV_8U), flann::SavedIndexParams([lshpath UTF8String]), cvflann::FLANN_DIST_HAMMING);
    [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(sendRequest) userInfo:nil repeats:YES];

    videoCamera = [[CvVideoCamera alloc] initWithParentView:previewImageView];
//    videoCamera = [[CvVideoCamera alloc] init];
    [videoCamera setDefaultAVCaptureDevicePosition:AVCaptureDevicePositionBack];
    [videoCamera setDefaultAVCaptureSessionPreset:AVCaptureSessionPreset640x480];
    [videoCamera setDefaultAVCaptureVideoOrientation:AVCaptureVideoOrientationPortrait];
    [videoCamera setDelegate:self];
//    [videoCamera setDefaultFPS:3];
    enable = YES;

    [videoCamera start];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)uploadAction:(id)sender {
    
    NSString *picPath = [[NSBundle mainBundle] pathForResource:@"pic_64" ofType:@"jpg"];
    NSData *data = [[NSData alloc] initWithContentsOfFile:picPath];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"http://10.102.20.24:8080/demo?upload=test"]];
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    [request setTimeoutInterval:20];

    [request setHTTPBody:data];
    NSString *postLength = [NSString stringWithFormat:@"%lu", [data length]];
    [request setValue:postLength forHTTPHeaderField:@"Content-Length"];

    NSHTTPURLResponse* urlResponse = nil;
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&urlResponse error:nil];

    NSString *result = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    NSLog(@"result: %@",result);
}

-(void)ransacAction {
    NSString *picPath = [[NSBundle mainBundle] pathForResource:@"700651049" ofType:@"jpg"];
    Mat image = imread([picPath UTF8String]);

    if(image.rows>image.cols) {
        int cols = FIX_SIZE*image.cols/image.rows;
        cv::resize(image, image, cv::Size(cols, FIX_SIZE));
    }
    else {
        int rows = FIX_SIZE*image.rows/image.cols;
        cv::resize(image, image, cv::Size(FIX_SIZE, rows));
    }

    Ptr<AKAZE> akaze = AKAZE::create();
    akaze->detectAndCompute(image, noArray(), kpts, desc);
    
    vector<Point2f> p01;
    vector<Point2f> p02;
    for(int i=0; i<kpts.size(); i++) {
        p01.push_back(Point2f(kpts[i].pt.x, kpts[i].pt.y));
        p02.push_back(Point2f(kpts[i].pt.x, kpts[i].pt.y));
    }
    
    vector<uchar> RansacStatus;
    
    Mat Fundamental = findFundamentalMat(p01, p02, RansacStatus, FM_RANSAC);
    
    int ransacCount = 0;
    for(int i=0; i<RansacStatus.size(); i++) {
        if(RansacStatus[i]!=0) {
            ransacCount++;
        }
    }
    NSLog(@"%d", ransacCount);
}
@end
