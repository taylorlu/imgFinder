//
//  MainViewController.m
//  imgFinder
//
//  Created by LuDong on 2018/8/28.
//  Copyright © 2018年 LuDong. All rights reserved.
//

#import "MainViewController.h"

@interface MainViewController ()

@end

@implementation MainViewController

- (void)retrieveCallback:(NSString *)cid {
    NSLog(@"cid ======== %@", cid);

}

- (void)viewDidLoad {
    [super viewDidLoad];

    retrieveObject = [[RetrieveObject alloc] init];
    [retrieveObject setRetrieveDelegate:self];
    
    // from stream.
//    [retrieveObject initRetrieve:@"http://10.102.25.22:9011/arImageHandle/search" :previewImageView];
    [retrieveObject initRetrieve:@"http://172.18.250.30:9011/arImageHandle/search" :previewImageView];
    [retrieveObject startRetrieve];
    isCapture = YES;
//    [retrieveObject stopRetrieve];
    
    // from local file or take photo.
//    UIImage *image = [UIImage imageNamed:@"pic2.png"];
//    [retrieveObject initPostImage:@"http://xxx"];
//    [retrieveObject postUIImage:image];
}

- (IBAction)clickAction:(id)sender {
    if(isCapture) {
        [retrieveObject initRetrieve:@"http://172.18.250.30:9011/arImageHandle/search" :previewImageView];
        [retrieveObject startRetrieve];
    }
    else {
        [retrieveObject stopRetrieve];
    }
    
    isCapture = !isCapture;
}
@end
