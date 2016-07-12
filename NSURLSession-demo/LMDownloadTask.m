//
//  LMDownloadTask.m
//  NSURLSession-demo
//  下载任务类，单例模式
//  Created by zhuo on 16/7/11.
//  Copyright © 2016年 zhuo. All rights reserved.
//

#import "LMDownloadTask.h"
#import "LMDownLoadModel.h"
#import "NSString+md5.h"

#define IS_IOS8ORLATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8)

NSString * const BackGroundConfigure = @"com.LMDownloadSessionManager.backgroundConfigure";

@interface LMDownloadTask ()
// 文件管理
@property (nonatomic, strong) NSFileManager *fileManager;
// 下载路径
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

- (void)startWithDownloadModel:(LMDownloadModel *)downloadModel progress:(LMDownloadProgressBlock)progress state:(LMDownloadStateBlock)state
{
    NSLog(@"%s", __func__);
    downloadModel.progressBlock = progress;
    downloadModel.stateBlock = state;
    
    [self startWithDownloadModel:downloadModel];
}

- (void)startWithDownloadModel:(LMDownloadModel *)downloadModel
{
    NSLog(@"%s", __func__);
    if (!downloadModel) {
        return;
    }
    
    if (downloadModel.state == LMDownloadOperationReadyState) {
        [self downloadModel:downloadModel didChangeState:LMDownloadOperationReadyState filePath:nil error:nil];
        return;
    }
    
    // 验证是否存在
    if (downloadModel.task && downloadModel.task.state == NSURLSessionTaskStateRunning) {
        downloadModel.state = LMDownloadOperationExecutingState;
        [self downloadModel:downloadModel didChangeState:LMDownloadOperationExecutingState filePath:nil error:nil];
        return;
    }
    
    // 后台下载设置
    [self configirebackgroundSessionTasksWithDownloadModel:downloadModel];
    
    [self resumeWithDownloadModel:downloadModel];
}

// 恢复下载
- (void)resumeWithDownloadModel:(LMDownloadModel *)downloadModel
{
    NSLog(@"%s", __func__);
    if (!downloadModel) {
        return;
    }
    
    if (![self canResumeDownlaodModel:downloadModel]) {
        return;
    }
    
    // 如果task 不存在 或者 取消了
    if (!downloadModel.task || downloadModel.task.state == NSURLSessionTaskStateCanceling) {
        
        NSData *resumeData = [self resumeDataFromFileWithDownloadModel:downloadModel];
        
        if ([self isValideResumeData:resumeData]) {
            downloadModel.task = [self.session downloadTaskWithResumeData:resumeData];
        }else {
            NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:downloadModel.downloadURL]];
            downloadModel.task = [self.session downloadTaskWithRequest:request];
        }
        downloadModel.task.taskDescription = downloadModel.downloadURL;
    }
    
    if (![self.downloadingModelDic objectForKey:downloadModel.downloadURL]) {
        self.downloadingModelDic[downloadModel.downloadURL] = downloadModel;
    }
    
    [downloadModel.task resume];
    
    downloadModel.state = LMDownloadOperationExecutingState;
    [self downloadModel:downloadModel didChangeState:LMDownloadOperationExecutingState filePath:nil error:nil];
}

// 暂停下载
- (void)suspendWithDownloadModel:(LMDownloadModel *)downloadModel
{
    if (!downloadModel.manualCancle) {
        downloadModel.manualCancle = YES;
        [self cancleWithDownloadModel:downloadModel clearResumeData:NO];
    }
}

// 取消下载 是否删除resumeData
- (void)cancleWithDownloadModel:(LMDownloadModel *)downloadModel clearResumeData:(BOOL)clearResumeData
{
    if (!downloadModel.task && downloadModel.state == LMDownloadOperationReadyState) {
        [self removeDownLoadingModelForURLString:downloadModel.downloadURL];
        @synchronized (self) {
            [self.waitingDownloadModels removeObject:downloadModel];
        }
        downloadModel.state = LMDonwloadOperationUnknown;
        [self downloadModel:downloadModel didChangeState:LMDonwloadOperationUnknown filePath:nil error:nil];
        return;
    }
    if (clearResumeData) {
        downloadModel.resumeData = nil;
        [downloadModel.task cancel];
    }else {
        [(NSURLSessionDownloadTask *)downloadModel.task cancelByProducingResumeData:^(NSData *resumeData){
        }];
    }
}

//取消下载
- (void)cancleWithDownloadModel:(LMDownloadModel *)downloadModel
{
    if (downloadModel.state != LMDownloadOperationFinishedState && downloadModel.state != LMDownloadOperationErrorState){
        [self cancleWithDownloadModel:downloadModel clearResumeData:NO];
    }
}

// 删除下载
- (void)deleteFileWithDownloadModel:(LMDownloadModel *)downloadModel
{
    if (!downloadModel || !downloadModel.filePath) {
        return;
    }
    
    [self cancleWithDownloadModel:downloadModel clearResumeData:YES];
    [self deleteFileIfExist:downloadModel.filePath];
}

#pragma mark - configire background task

// 配置后台后台下载session
- (void)configirebackgroundSessionTasksWithDownloadModel:(LMDownloadModel *)downloadModel
{
    if (!_backgroundConfigure) {
        return ;
    }
    
    NSURLSessionDownloadTask *task = [self backgroundSessionTasksWithDownloadModel:downloadModel];
    if (!task) {
        return;
    }
    
    downloadModel.task = task;
    if (task.state == NSURLSessionTaskStateRunning) {
        [task suspend];
    }
}

- (NSURLSessionDownloadTask *)backgroundSessionTasksWithDownloadModel:(LMDownloadModel *)downloadModel
{
    NSArray *tasks = [self sessionDownloadTasks];
    for (NSURLSessionDownloadTask *task in tasks) {
        if (task.state == NSURLSessionTaskStateRunning || task.state == NSURLSessionTaskStateSuspended) {
            if ([downloadModel.downloadURL isEqualToString:task.taskDescription]) {
                return task;
            }
        }
    }
    return nil;
}

// 获取配置的后台下载session
- (NSArray *)sessionDownloadTasks
{
    __block NSArray *tasks = nil;
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    [self.session getTasksWithCompletionHandler:^(NSArray *dataTasks, NSArray *uploadTasks, NSArray *downloadTasks) {
        tasks = downloadTasks;
        dispatch_semaphore_signal(semaphore);
    }];
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return tasks;
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
        _downloadDirectory = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"cacheDownLoad"];
        [self createDirectory:_downloadDirectory];
        NSLog(@"%s, download dic = %@", __func__,_downloadDirectory);
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
    if (_delegate && [_delegate respondsToSelector:@selector(downloadModel:didChangeState:filePath:error:)]) {
        [_delegate downloadModel:downloadModel didChangeState:state filePath:filePath error:error];
    }
    
    if (downloadModel.stateBlock) {
        downloadModel.stateBlock(state,filePath,error);
    }
}

- (void)downloadModel:(LMDownloadModel *)downloadModel updateProgress:(LMDownloadProgress *)progress
{
    if (_delegate && [_delegate respondsToSelector:@selector(downloadModel:didUpdateProgress:)]) {
        [_delegate downloadModel:downloadModel didUpdateProgress:progress];
    }
    
    if (downloadModel.progressBlock) {
        downloadModel.progressBlock(progress);
    }
}

// 从下载队列中删除model
- (void)removeDownLoadingModelForURLString:(NSString *)URLString
{
    [self.downloadingModelDic removeObjectForKey:URLString];
}

// 获取resumeData
- (NSData *)resumeDataFromFileWithDownloadModel:(LMDownloadModel *)downloadModel
{
    if (downloadModel.resumeData) {
        return downloadModel.resumeData;
    }
    NSString *resumeDataPath = [self resumeDataPathWithDownloadURL:downloadModel.downloadURL];
    
    if ([_fileManager fileExistsAtPath:resumeDataPath]) {
        NSData *resumeData = [NSData dataWithContentsOfFile:resumeDataPath];
        return resumeData;
    }
    return nil;
}

// resumeData 路径
- (NSString *)resumeDataPathWithDownloadURL:(NSString *)downloadURL
{
   // NSString *resumeFileName = [NSString md5:downloadURL];
    return [self.downloadDirectory stringByAppendingPathComponent:downloadURL.lastPathComponent];
}

// 用于保存下载可以恢复下载
- (void)willResumeNextWithDowloadModel:(LMDownloadModel *)downloadModel
{
    @synchronized (self) {
        [self.downloadingModels removeObject:downloadModel];
        // 还有未下载的
        if (self.waitingDownloadModels.count > 0) {
            [self resumeWithDownloadModel:self.waitingDownloadModels.firstObject];
        }
    }
}

// 检验是否可以恢复下载
- (BOOL)canResumeDownlaodModel:(LMDownloadModel *)downloadModel
{
    @synchronized (self) {
        if (self.downloadingModels.count >= _maxDownloadCount ) {
            if ([self.waitingDownloadModels indexOfObject:downloadModel] == NSNotFound) {
                [self.waitingDownloadModels addObject:downloadModel];
                self.downloadingModelDic[downloadModel.downloadURL] = downloadModel;
            }
            downloadModel.state = LMDownloadOperationReadyState;
            [self downloadModel:downloadModel didChangeState:LMDownloadOperationReadyState filePath:nil error:nil];
            return NO;
        }
        
        if ([self.waitingDownloadModels indexOfObject:downloadModel] != NSNotFound) {
            [self.waitingDownloadModels removeObject:downloadModel];
        }
        
        if ([self.downloadingModels indexOfObject:downloadModel] == NSNotFound) {
            [self.downloadingModels addObject:downloadModel];
        }
        return YES;
    }
}
/** 检查url是否可用*/
- (BOOL)isValideResumeData:(NSData *)resumeData
{
    if (!resumeData || resumeData.length == 0) {
        return NO;
    }
    return YES;
}

#pragma -mark NSURLSessionDownloadDelegate

/**
 *  NSURLSessionDownloadDelegate委托协议
 *  下载完毕就会调用一次这个方法
 *
 *  @param session      session
 *  @param downloadTask sessiontask
 *  @param location     储存的临时文件路径
 */
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location {
    NSLog(@"%s", __func__);
    LMDownloadModel *downloadModel = [self downLoadingModelForURLString:downloadTask.taskDescription];
    if (!downloadModel) return;
    
    if (location) {
        // 移动文件到下载目录
        [self createDirectory:downloadModel.downloadDirectory];
        [self moveFileAtURL:location toPath:downloadModel.filePath];
        NSLog(@"%@", downloadModel.downloadDirectory);
    }

    
}
/**
 * NSURLSessionDownloadDelegate委托协议
 *  非正常下载完成时调用，用来做离线下载
 *  @param session session
 *  @param task    task
 *  @param error   错误信息，有可能没有
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
didCompleteWithError:(nullable NSError *)error {
    
    NSLog(@"%s", __func__);
    LMDownloadModel *downloadModel = [self downLoadingModelForURLString:task.taskDescription];
    
    if (!downloadModel) {
        NSData *resumeData = error ? [error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData]:nil;
        if (resumeData) {
            [self createDirectory:_downloadDirectory];
            [resumeData writeToFile:[self resumeDataPathWithDownloadURL:task.taskDescription] atomically:YES];
        }else {
            [self deleteFileIfExist:[self resumeDataPathWithDownloadURL:task.taskDescription]];
        }
        return;
    }
    
    NSData *resumeData = nil;
    if (error) {
        resumeData = [error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData];
    }
    // 缓存resumeData
    if (resumeData) {
        downloadModel.resumeData = resumeData;
        [self createDirectory:_downloadDirectory];
        [downloadModel.resumeData writeToFile:[self resumeDataPathWithDownloadURL:downloadModel.downloadURL] atomically:YES];
    }else {
        downloadModel.resumeData = nil;
        [self deleteFileIfExist:[self resumeDataPathWithDownloadURL:downloadModel.downloadURL]];
    }
    
    downloadModel.progress.resumeBytesWritten = 0;
    downloadModel.task = nil;
    [self removeDownLoadingModelForURLString:downloadModel.downloadURL];
    
    if (downloadModel.manualCancle) {
        // 手动取消，当做暂停
        dispatch_async(dispatch_get_main_queue(), ^(){
            downloadModel.manualCancle = NO;
            downloadModel.state = LMDownloadOperationPausedState;
            [self downloadModel:downloadModel didChangeState:LMDownloadOperationPausedState filePath:nil error:nil];
            [self willResumeNextWithDowloadModel:downloadModel];
        });
    }else if (error){
        // 下载失败
        dispatch_async(dispatch_get_main_queue(), ^(){
            downloadModel.state = LMDownloadOperationErrorState;
            [self downloadModel:downloadModel didChangeState:LMDownloadOperationErrorState filePath:nil error:error];
            [self willResumeNextWithDowloadModel:downloadModel];
        });
    }else {
        // 下载完成
        dispatch_async(dispatch_get_main_queue(), ^(){
            downloadModel.state = LMDownloadOperationFinishedState;
            [self downloadModel:downloadModel didChangeState:LMDownloadOperationFinishedState filePath:downloadModel.filePath error:nil];
            [self willResumeNextWithDowloadModel:downloadModel];
        });
    }

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
    NSLog(@"%s", __func__);
    LMDownloadModel *downloadModel = [self downLoadingModelForURLString:downloadTask.taskDescription];
    
    if (!downloadModel || downloadModel.state == LMDownloadOperationPausedState) {
        return;
    }
    downloadModel.progress.resumeBytesWritten = fileOffset;
}

@end
