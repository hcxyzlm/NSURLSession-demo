//
//  ViewController.m
//  TYDownloadManagerDemo
//
//  Created by tany on 16/6/12.
//  Copyright © 2016年 tany. All rights reserved.
//

#import "DownloadSessionViewController.h"
#import "LMDownloadTask.h"
#import <MediaPlayer/MediaPlayer.h>
#import "LMDownLoadModel.h"
#import "LMDownloadDelegate.h"

@interface DownloadSessionViewController ()

@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UIButton *downloadBtn;
@property (weak, nonatomic) IBOutlet UILabel *progressLabel;

@property (nonatomic,strong) LMDownloadModel *downloadModel;
@end

static NSString * const downloadUrl = @"http://dlsw.baidu.com/sw-search-sp/soft/94/23191/BaiduWubi_1.2.0.66_Setup.1447990267.exe";

@implementation DownloadSessionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}


- (IBAction)download:(id)sender {
    [self startDownlaod];
}

- (void)startDownlaod
{
    NSLog(@"%s", __func__);
    LMDownloadTask *manager = [LMDownloadTask shareDonwLoadTask];
    _downloadModel = [[LMDownloadModel alloc] initWithURLString:downloadUrl];
    __weak typeof(self) weakSelf = self;
    [manager startWithDownloadModel:_downloadModel progress:^(LMDownloadProgress *progress) {
        weakSelf.progressView.progress = progress.progress;
        weakSelf.progressLabel.text = [NSString stringWithFormat:@"progress %.2f",weakSelf.progressView.progress];
        
    } state:^(LMDownloadOperationState state, NSString *filePath, NSError *error) {
        if (state == LMDownloadOperationFinishedState) {
            weakSelf.progressView.progress = 1.0;
            weakSelf.progressLabel.text = [NSString stringWithFormat:@"progress %.2f",weakSelf.progressView.progress];
        }
    }];
}
- (IBAction)pauseDownLoad:(id)sender {
    _downloadModel = [[LMDownloadTask shareDonwLoadTask] downLoadingModelForURLString:downloadUrl];
    if (_downloadModel) {
        [[LMDownloadTask shareDonwLoadTask] suspendWithDownloadModel:_downloadModel];
    }
}
- (IBAction)deleteDownLoad:(id)sender {
    _downloadModel = [[LMDownloadTask shareDonwLoadTask] downLoadingModelForURLString:downloadUrl];
    if (_downloadModel) {
        [[LMDownloadTask shareDonwLoadTask] deleteFileWithDownloadModel:_downloadModel];
    }
}
#pragma mark - LMDownloadDelegate


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
