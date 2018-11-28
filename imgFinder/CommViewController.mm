//
//  CommViewController.m
//  imgFinder
//
//  Created by LuDong on 2018/8/9.
//  Copyright © 2018年 LuDong. All rights reserved.
//

#import "CommViewController.h"

@interface CommViewController ()

@end

@implementation CommViewController

Mat wholeData;

lshbox::rbsLsh initLSH() {

    lshbox::rbsLsh::Parameter param;
    param.M = 60000;
    param.L = 5;
    param.D = 61;
    param.C = 256; // ◊Ó¥Û÷µ
    param.N = 20;
    
    unsigned i1[20] = {528, 918, 1001, 1665, 2133, 3471, 3483, 4055, 4438, 6076, 6676, 7293, 10498, 13265, 13386, 13461, 14521, 14891, 15377, 15385};
    std::vector<unsigned> inner1(i1, i1+20);
    unsigned i2[20] = {187, 1888, 3186, 3388, 3693, 3836, 3880, 4741, 5272, 6594, 9046, 10273, 10897, 11379, 11852, 12004, 12511, 12939, 13606, 13845};
    std::vector<unsigned> inner2(i2, i2+20);
    unsigned i3[20] = {1345, 2532, 3014, 3157, 5160, 6344, 6735, 6990, 7846, 8504, 8905, 9890, 10551, 11259, 11466, 11620, 11751, 12566, 13161, 13817};
    std::vector<unsigned> inner3(i3, i3+20);
    unsigned i4[20] = {358, 460, 815, 1877, 2012, 2217, 2547, 4300, 4651, 5502, 5675, 5831, 5944, 6764, 7385, 7417, 9137, 9292, 11116, 12988};
    std::vector<unsigned> inner4(i4, i4+20);
    unsigned i5[20] = {387, 625, 1491, 2411, 2649, 3320, 3824, 3970, 4899, 4968, 5543, 6594, 7126, 7847, 11114, 11134, 12485, 13826, 14020, 15235};
    std::vector<unsigned> inner5(i5, i5+20);
    
    
    std::vector<std::vector<unsigned>> usBits;
    usBits.push_back(inner1);
    usBits.push_back(inner2);
    usBits.push_back(inner3);
    usBits.push_back(inner4);
    usBits.push_back(inner5);
    
    unsigned i11[20] = {23924, 28276, 8031, 6580, 43789, 9081, 16918, 34659, 51900, 55180, 57784, 17818, 10559, 1040, 881, 19117, 93, 44385, 43813, 59652};
    std::vector<unsigned> inner11(i11, i11+20);
    unsigned i22[20] = {25458, 33972, 57492, 48193, 5462, 58595, 25983, 21588, 53335, 53763, 19379, 32928, 26813, 42550, 51085, 1006, 59521, 30023, 12991, 32272};
    std::vector<unsigned> inner22(i22, i22+20);
    unsigned i33[20] = {49207, 9180, 16847, 35388, 33724, 24982, 20528, 3567, 21624, 57233, 47598, 43215, 43817, 22289, 48850, 12899, 59273, 6530, 51541, 42281};
    std::vector<unsigned> inner33(i33, i33+20);
    unsigned i44[20] = {37049, 37695, 7750, 28100, 43828, 2205, 4589, 57731, 33606, 50810, 19464, 26175, 53030, 32609, 57613, 5081, 15626, 19844, 15251, 58653};
    std::vector<unsigned> inner44(i44, i44+20);
    unsigned i55[20] = {59908, 39328, 24239, 51237, 52568, 31596, 7682, 14730, 40079, 17757, 54678, 22571, 34432, 6009, 55219, 31907, 52263, 23548, 49410, 3731};
    std::vector<unsigned> inner55(i55, i55+20);
    
    
    std::vector<std::vector<unsigned>> usArray;
    usArray.push_back(inner11);
    usArray.push_back(inner22);
    usArray.push_back(inner33);
    usArray.push_back(inner44);
    usArray.push_back(inner55);
    
    lshbox::rbsLsh mylsh;
    mylsh.reset(param, usBits, usArray);
    return mylsh;

}

- (void)processImage:(Mat&)image {
    

    
    Ptr<AKAZE> akaze = AKAZE::create();
    akaze->detectAndCompute(image, noArray(), kpts, desc);
    
    NSURL *url = [NSURL URLWithString:@"http://127.0.0.1:9090/demo"];
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    [request setTimeoutInterval:20];
    NSMutableData *data = [[NSMutableData alloc] init];
    
    for (int i=0;i<kpts.size(); i++) {
        unsigned *lineData = (unsigned *)(desc.data + i*desc.step[0]);
        for(int k=0; k<L; k++) {
            short hashVal = (short)mylsh.getHashVal(k, lineData);
            [data appendBytes:(void*)&hashVal length:sizeof(short)];
        }
        short ptx = (short)kpts[i].pt.x;
        [data appendBytes:(void*)&ptx length:sizeof(short)];
        short pty = (short)kpts[i].pt.y;
        [data appendBytes:(void*)&pty length:sizeof(short)];
    }
    [request setHTTPBody:data];
    
    NSURLSession *sess = [NSURLSession sharedSession];
    
    NSURLSessionDataTask *uploadtask = [sess dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        

    }];
    [uploadtask resume];
    NSLog(@"%@", [url path]);
}

- (void)viewDidLoad {
    [self viewDidLoad];
    
    videoCamera = [[CvVideoCamera alloc] initWithParentView:previewImageView];
    [videoCamera setDefaultAVCaptureDevicePosition:AVCaptureDevicePositionBack];
    [videoCamera setDefaultAVCaptureSessionPreset:AVCaptureSessionPreset640x480];
    [videoCamera setDefaultAVCaptureVideoOrientation:AVCaptureVideoOrientationPortrait];
    [videoCamera setDelegate:self];
    
    [videoCamera start];
    enable = YES;
    L = 5;
    N = 20;
    mylsh = initLSH();

    
}

- (IBAction)subaction:(id)sender {
    NSString *toPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"wholeData.yml"];
    cv::FileStorage fs([toPath UTF8String], cv::FileStorage::WRITE);
    fs << "resultMat" << wholeData;
    fs.release();
}

- (IBAction)click:(id)sender {
    
    if(enable) {
        enable = NO;
        [videoCamera stop];
        wholeData.push_back(desc);
        NSLog(@"%d, %d", wholeData.cols, wholeData.rows);
    }
    else {
        enable = YES;
        [videoCamera start];
    }
    
}
@end
