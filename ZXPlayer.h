//
//  ZXPlayer.h
//  Hospital
//
//  Created by FZX on 2018/6/11.
//  Copyright © 2018年 wangbao. All rights reserved.
//

#import <Foundation/Foundation.h>
typedef void(^RecordBlock)(NSData *data);
@interface ZXPlayer : NSObject
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, copy) RecordBlock callback;

+ (instancetype)sharedInstance;
- (void)playerSoundWithUrl:(NSString *)urlString;
- (void)stop;

- (void)startRecord;
- (void)endRecord:(void(^)(NSData  *data))success;
- (void)playMp3;

- (void)playerVoiceWithUrl:(NSString *)urlString progress:(void(^)(CGFloat current, CGFloat total))progress end:(void(^)(NSString *status))end;

@end
