//
//  ViewController.m
//  NSURLSession-demo
//
//  Created by zhuo on 16/7/11.
//  Copyright © 2016年 zhuo. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()<NSURLSessionDownloadDelegate>


@property (nonatomic, strong) NSData *data;
/** NSURLSession*/
@property (nonatomic, strong) NSURLSession *sharedSession;
@property (nonatomic, strong) NSOperationQueue *queue;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self NSURLSessionTest];
}

- (void)NSURLSessionTest {
    // url
    NSURL *urlString = [NSURL URLWithString:@"http://sw.bos.baidu.com/sw-search-sp/software/7885baf791a/jpwb_3.2.21.72_setup.exe"];
    NSURLRequest *request = [NSURLRequest requestWithURL:urlString];
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    self.queue = [[NSOperationQueue alloc] init];
    // 并发数
    self.queue.maxConcurrentOperationCount = 1;
   // 3.采用苹果提供的共享session
    _sharedSession  = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:self.queue];
    
    NSURLSessionDownloadTask *downloadTask = [_sharedSession downloadTaskWithRequest:request];
    // 5.开启任务
    [downloadTask resume];
}

#pragma -mark delegate

/**
 *  NSURLSessionDownloadDelegate委托协议
 *
 *  @param session                   session
 *  @param downloadTask              sessiontask
 *  @param bytesWritten              每次下载的字节
 *  @param totalBytesWritten         已下载的字节
 *  @param totalBytesExpectedToWrite 总字节
 */
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    NSLog(@"%s", __func__);
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didResumeAtOffset:(int64_t)fileOffset expectedTotalBytes:(int64_t)expectedTotalBytes {
    NSLog(@"%s", __func__);
}

/**
 *  NSURLSessionDownloadDelegate委托协议
 *
 *  @param session      session
 *  @param downloadTask sessiontask
 *  @param location     储存的临时文件路径
 */
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(NSURL *)location {
    
    NSFileManager *manager = [NSFileManager defaultManager];
    //获取document目录
    NSString *strDocument = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).lastObject;
    //在原有路径上添加路径
    NSLog(@"current thread = %@", [NSThread currentThread]);
    NSString *strURL = [strDocument stringByAppendingPathComponent:@"qq.exe"];
    NSLog(@"%@", strURL);
    //本地URL路径
    NSURL *url = [NSURL fileURLWithPath:strURL];
    
    if ([manager fileExistsAtPath:strURL]) {
        [manager removeItemAtPath:strURL error:nil];
    }
    //把tem文件移动指定的URL路径上
    if ([manager moveItemAtURL:location toURL:url error:nil]) {
        _data = [manager contentsAtPath:strURL];
        
    }
}
@end
