//
//  LMDownLoadModel.m
//  NSURLSession-demo
//  下载模型类
//  Created by zhuo on 16/7/11.
//  Copyright © 2016年 zhuo. All rights reserved.
//

#import "LMDownLoadModel.h"

@implementation LMDownloadModel

- (instancetype)init
{
    self = [super init];
    if (self) {
        _progress = [[LMDownloadProgress alloc] init];
    }
    return self;
}
- (instancetype)initWithURLString:(NSString *)URLString
{
    return [self initWithURLString:URLString filePath:nil];
}

- (instancetype)initWithURLString:(NSString *)URLString filePath:(NSString *)filePath
{
    if (self = [self init]) {
        _downloadURL = URLString;
        _fileName = filePath.lastPathComponent;
        _downloadDirectory = filePath.stringByDeletingLastPathComponent;
        _filePath = filePath;
    }
    return self;
}

-(NSString *)fileName
{
    if (!_fileName) {
        _fileName = _downloadURL.lastPathComponent;
    }
    return _fileName;
}

- (NSString *)downloadDirectory
{
    if (!_downloadDirectory) {
        _downloadDirectory = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"newdownload"];
    }
    return _downloadDirectory;
}

- (NSString *)filePath
{
    if (!_filePath) {
        _filePath = [self.downloadDirectory stringByAppendingPathComponent:self.fileName];
    }
    return _filePath;
}

@end

@implementation LMDownloadProgress

@end
