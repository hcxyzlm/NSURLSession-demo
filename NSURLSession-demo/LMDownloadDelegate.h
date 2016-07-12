//
//  TYDownloadDelegate.h
//  TYDownloadManagerDemo
//
//  Created by tany on 16/6/24.
//  Copyright © 2016年 tany. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LMDownloadModel.h"

// 下载代理
@protocol LMDownloadDelegate <NSObject>

// 更新下载进度
- (void)downloadModel:(LMDownloadModel *)downloadModel didUpdateProgress:(LMDownloadProgress *)progress;

// 更新下载状态
- (void)downloadModel:(LMDownloadModel *)downloadModel didChangeState:(LMDownloadState)state filePath:(NSString *)filePath error:(NSError *)error;

@end
