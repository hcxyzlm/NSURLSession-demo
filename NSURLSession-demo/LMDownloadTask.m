//
//  LMDownloadTask.m
//  NSURLSession-demo
//  下载任务类，单例模式
//  Created by zhuo on 16/7/11.
//  Copyright © 2016年 zhuo. All rights reserved.
//

#import "LMDownloadTask.h"
#import "LMDownLoadModel.h"

#define IS_IOS8ORLATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8)

NSString * const BackGroundConfigure = @"com.LMDownloadSessionManager.backgroundConfigure";

@interface LMDownloadTask ()
// 文件管理
@property (nonatomic, strong) NSFileManager *fileManager;
// 下载
@property (nonatomic, strong) NSString *downloadDirectory;

// 下载seesion会话
@property (nonatomic, strong) NSURLSession *session;
// 下载模型字典 key = url, value = model
@property (nonatomic, strong) NSMutableDictionary *downloadingModelDic;
// 下载中的模型
@property (nonatomic, strong) NSMutableArray *waitingDownloadModels;
// 等待中的模型
@property (nonatomic, strong) NSMutableArray *downloadingModels;
// 回调代理的队列
@property (strong, nonatomic) NSOperationQueue *queue;

@end


@implementation LMDownloadTask

#pragma  -mark init
/**
 *  类方法
 *
 *  @return 返回单例
 */
+ (LMDownloadTask *)shareDonwLoadTask {
    
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    
    return sharedInstance;
}
- (instancetype)init
{
    if (self = [super init]) {
        _backgroundConfigure = BackGroundConfigure;
        _maxDownloadCount = 1;
    }
    return self;
}

#pragma -mark download
- (LMDownloadModel *)startDownloadURLString:(NSString *)URLString toDestinationPath:(NSString *)destinationPath progress:(LMDownloadProgressBlock)progress state:(LMDownloadStateBlock)state {
    // 验证下载地址
    if (!URLString) {
        NSLog(@"dwonloadURL can't nil");
        return nil;
    }
    
    LMDownloadModel *downloadModel = [self downLoadingModelForURLString:URLString];
    
    if (!downloadModel || ![downloadModel.filePath isEqualToString:destinationPath]) {
        downloadModel = [[LMDownloadModel alloc]initWithURLString:URLString filePath:destinationPath];
    }
    
    [self startWithDownloadModel:downloadModel progress:progress state:state];
    
    return downloadModel;

}
- (void)startWithDownloadModel:(LMDownloadModel *)downloadModel progress:(LMDownloadProgressBlock)progress state:(LMDownloadStateBlock)state {
    
}

#pragma public
// 获取正在下载模型
- (LMDownloadModel *)downLoadingModelForURLString:(NSString *)URLString {
    return [self.downloadingModelDic objectForKey:URLString];
}

#pragma getter/stter
- (NSFileManager *)fileManager
{
    if (!_fileManager) {
        _fileManager = [[NSFileManager alloc]init];
    }
    return _fileManager;
}

- (NSURLSession *)session
{
    if (!_session) {
        if (_backgroundConfigure) {
            if (IS_IOS8ORLATER) {
                _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:_backgroundConfigure]delegate:self delegateQueue:self.queue];
            }else{
                _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration backgroundSessionConfiguration:_backgroundConfigure]delegate:self delegateQueue:self.queue];
            }
        }else {
            _session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:self.queue];
        }
    }
    return _session;
}

- (NSOperationQueue *)queue
{
    if (!_queue) {
        _queue = [[NSOperationQueue alloc]init];
        _queue.maxConcurrentOperationCount = 1;
    }
    return _queue;
}

- (NSString *)downloadDirectory
{
    if (!_downloadDirectory) {
        _downloadDirectory = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"DownloadCache"];
        [self createDirectory:_downloadDirectory];
    }
    return _downloadDirectory;
}

- (NSMutableDictionary *)downloadingModelDic
{
    if (!_downloadingModelDic) {
        _downloadingModelDic = [NSMutableDictionary dictionary];
    }
    return _downloadingModelDic;
}

- (NSMutableArray *)waitingDownloadModels
{
    if (!_waitingDownloadModels) {
        _waitingDownloadModels = [NSMutableArray array];
    }
    return _waitingDownloadModels;
}

- (NSMutableArray *)downloadingModels
{
    if (!_downloadingModels) {
        _downloadingModels = [NSMutableArray array];
    }
    return _downloadingModels;
}

#pragma -mark inlone methods
//  创建缓存目录文件
- (void)createDirectory:(NSString *)directory
{
    if (![self.fileManager fileExistsAtPath:directory]) {
        [self.fileManager createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:NULL];
    }
}

- (void)moveFileAtURL:(NSURL *)srcURL toPath:(NSString *)dstPath
{
    NSError *error = nil;
    if ([self.fileManager fileExistsAtPath:dstPath] ) {
        [self.fileManager removeItemAtPath:dstPath error:&error];
        if (error) {
            NSLog(@"removeItem error %@",error);
        }
    }
    
    NSURL *dstURL = [NSURL fileURLWithPath:dstPath];
    [self.fileManager moveItemAtURL:srcURL toURL:dstURL error:&error];
    if (error){
        NSLog(@"moveItem error:%@",error);
    }
}

- (void)deleteFileIfExist:(NSString *)filePath
{
    if ([self.fileManager fileExistsAtPath:filePath] ) {
        NSError *error  = nil;
        [self.fileManager removeItemAtPath:filePath error:&error];
        if (error) {
            NSLog(@"emoveItem error %@",error);
        }
    }
}

#pragma mark - private

- (void)downloadModel:(LMDownloadModel *)downloadModel didChangeState:(LMDownloadOperationState)state filePath:(NSString *)filePath error:(NSError *)error
{
//    if (_delegate && [_delegate respondsToSelector:@selector(downloadModel:didChangeState:filePath:error:)]) {
//        [_delegate downloadModel:downloadModel didChangeState:state filePath:filePath error:error];
//    }
    
    if (downloadModel.stateBlock) {
        downloadModel.stateBlock(state,filePath,error);
    }
}

- (void)downloadModel:(LMDownloadModel *)downloadModel updateProgress:(LMDownloadProgress *)progress
{
//    if (_delegate && [_delegate respondsToSelector:@selector(downloadModel:didUpdateProgress:)]) {
//        [_delegate downloadModel:downloadModel didUpdateProgress:progress];
//    }
    
    if (downloadModel.progressBlock) {
        downloadModel.progressBlock(progress);
    }
}

#pragma -mark NSURLSessionDownloadDelegate

/**
 *  NSURLSessionDownloadDelegate委托协议
 *  下载完成调用
 *
 *  @param session      session
 *  @param downloadTask sessiontask
 *  @param location     储存的临时文件路径
 */
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {
    
}

/**
 *  NSURLSessionDownloadDelegate委托协议
 *  会调用多次
 *  @param session                   session
 *  @param downloadTask              sessiontask
 *  @param bytesWritten              每次下载的字节
 *  @param totalBytesWritten         已下载的字节
 *  @param totalBytesExpectedToWrite 总字节
*/
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    LMDownloadModel *downloadModel = [self downLoadingModelForURLString:downloadTask.taskDescription];
    
    if (!downloadModel || downloadModel.state == LMDownloadOperationPausedState) {
        return;
    }
    
    float progress = (double)totalBytesWritten/totalBytesExpectedToWrite;
    downloadModel.progress.bytesWritten = bytesWritten;
    downloadModel.progress.totalBytesWritten = totalBytesWritten;
    downloadModel.progress.totalBytesExpectedToWrite = totalBytesExpectedToWrite;
    downloadModel.progress.progress = progress;
    
    dispatch_async(dispatch_get_main_queue(), ^(){
        [self downloadModel:downloadModel updateProgress:downloadModel.progress];
    });

}

/**
 *  NSURLSessionDownloadDelegate委托协议
 *  中断恢复下载
 *  @param session            session
 *  @param downloadTask       sessiontask
 *  @param fileOffset         文件指针
 *  @param expectedTotalBytes 总字节
 */
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didResumeAtOffset:(int64_t)fileOffset
expectedTotalBytes:(int64_t)expectedTotalBytes {
    
    LMDownloadModel *downloadModel = [self downLoadingModelForURLString:downloadTask.taskDescription];
    
    if (!downloadModel || downloadModel.state == LMDownloadOperationPausedState) {
        return;
    }
    downloadModel.progress.resumeBytesWritten = fileOffset;
}

@end
