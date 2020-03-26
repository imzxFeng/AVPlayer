//
//  ZXPlayer.m
//  Hospital
//
//  Created by FZX on 2018/6/11.
//  Copyright © 2018年 wangbao. All rights reserved.
//

#import "ZXPlayer.h"
#import "lame.h"
static ZXPlayer *staticPlayer;
@interface ZXPlayer ()<AVAudioRecorderDelegate,AVAudioPlayerDelegate>

@property (nonatomic, strong)AVPlayer *player;
@property (nonatomic, strong) id timeObserve;
@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (nonatomic, strong) AVAudioSession *audioSession;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;

@end
@implementation ZXPlayer
{
    BOOL isPlaying;
    BOOL isPause;
    NSString *lastUrl;
    NSURL *recordUrl;
    NSURL *mp3FilePath;
}

+ (instancetype)sharedInstance
{
    if (!staticPlayer){
        static dispatch_once_t token ;
        dispatch_once(&token, ^{
            staticPlayer = [[ZXPlayer alloc] init];
        });
    }
    return staticPlayer;
}

- (void)stop{
    [_player pause];
}

- (void)setIsPlaying:(BOOL)isPlaying{
    _isPlaying = isPlaying;
}

- (void)playerSoundWithUrl:(NSString *)urlString{
    if (![urlString isEqualToString:lastUrl]) {
        _isPlaying = NO;
        isPause = NO;
    }
    if (isPause) {
        [_player play];
        isPlaying = YES;
        isPause = NO;
        return;
    }
    if (_isPlaying) {
        [_player pause];
        _isPlaying = NO;
        isPause = YES;
        return;
    }
    
    NSURL * url  = [NSURL URLWithString:urlString];
    
    lastUrl = urlString;
  
    AVPlayerItem * songItem = [[AVPlayerItem alloc]initWithURL:url];
    _player = [[AVPlayer alloc]initWithPlayerItem:songItem];
    if([[UIDevice currentDevice] systemVersion].intValue>=10){
        //      增加下面这行可以解决iOS10兼容性问题了
        self.player.automaticallyWaitsToMinimizeStalling = NO;
    }
    
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:&error];
    
    
    //监控状态属性，注意AVPlayer也有一个status属性，通过监控它的status也可以获得播放状态
    [self.player.currentItem addObserver:self forKeyPath:@"status" options:(NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew) context:nil];
    
    
    
    _timeObserve = [_player addPeriodicTimeObserverForInterval:CMTimeMake(1.0, 1.0) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        float current = CMTimeGetSeconds(time);
        float total = CMTimeGetSeconds(songItem.duration);
        if (current) {
            NSLog(@"current ---- %.2f    total ---- %.2f",current,total);
            if (current == total) {
                _isPlaying = NO;
                isPause = NO;
            }
        }
    }];
}

- (void)playerVoiceWithUrl:(NSString *)urlString
                  progress:(void(^)(CGFloat current, CGFloat total))progress
                       end:(void(^)(NSString *status))end{
    if (![urlString isEqualToString:lastUrl]) {
        _isPlaying = NO;
    }
    
    if (_isPlaying) {
        [_player pause];
        _isPlaying = NO;
        return;
    }
    
    NSURL * url  = [NSURL URLWithString:urlString];
    
    lastUrl = urlString;
    
    AVPlayerItem * songItem = [[AVPlayerItem alloc]initWithURL:url];
    _player = [[AVPlayer alloc]initWithPlayerItem:songItem];
    if([[UIDevice currentDevice] systemVersion].intValue>=10){
        //      增加下面这行可以解决iOS10兼容性问题了
        self.player.automaticallyWaitsToMinimizeStalling = NO;
    }
    
    NSError *error = nil;
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryAmbient error:&error];
    
    
    //监控状态属性，注意AVPlayer也有一个status属性，通过监控它的status也可以获得播放状态
    [self.player.currentItem addObserver:self forKeyPath:@"status" options:(NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew) context:nil];
    
    
    
    _timeObserve = [_player addPeriodicTimeObserverForInterval:CMTimeMake(1.0, 1.0) queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        float current = CMTimeGetSeconds(time);
        float total = CMTimeGetSeconds(songItem.duration);
        if (current) {
            NSLog(@"current ---- %.2f    total ---- %.2f",current,total);
            progress(current,total);
            if (current == total) {
                _isPlaying = NO;
                end(@"1");
            }
        }
    }];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    
    if ([keyPath isEqualToString:@"status"]) {
        switch (self.player.status) {
            case AVPlayerStatusUnknown:
                NSLog(@"未知状态，此时不能播放");
                break;
            case AVPlayerStatusReadyToPlay:
                NSLog(@"KVO：准备完毕，可以播放");
                [_player play];
                _isPlaying = YES;
                isPause = NO;
                break;
            case AVPlayerStatusFailed:
                NSLog(@"KVO：加载失败，网络或者服务器出现问题");
                break;
            default:
                break;
        }
    }
}


- (void)startRecord
{
    //删除上次生成的文件，保留最新文件
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([NSTemporaryDirectory() stringByAppendingString:@"myselfRecord.mp3"]) {
        [fileManager removeItemAtPath:[NSTemporaryDirectory() stringByAppendingString:@"myselfRecord.mp3"] error:nil];
    }
    if ([NSTemporaryDirectory() stringByAppendingString:@"selfRecord.wav"]) {
        [fileManager removeItemAtPath:[NSTemporaryDirectory() stringByAppendingString:@"selfRecord.wav"] error:nil];
    }
    
    //开始录音
    //录音设置
    NSMutableDictionary *recordSetting = [[NSMutableDictionary alloc] init];
    //设置录音格式  AVFormatIDKey==kAudioFormatLinearPCM
    [recordSetting setValue:[NSNumber numberWithInt:kAudioFormatLinearPCM] forKey:AVFormatIDKey];
    //设置录音采样率(Hz) 如：AVSampleRateKey==8000/44100/96000（影响音频的质量）, 采样率必须要设为11025才能使转化成mp3格式后不会失真
    [recordSetting setValue:[NSNumber numberWithFloat:11025.0] forKey:AVSampleRateKey];
    //录音通道数  1 或 2 ，要转换成mp3格式必须为双通道
    [recordSetting setValue:[NSNumber numberWithInt:2] forKey:AVNumberOfChannelsKey];
    //线性采样位数  8、16、24、32
    [recordSetting setValue:[NSNumber numberWithInt:16] forKey:AVLinearPCMBitDepthKey];
    //录音的质量
    [recordSetting setValue:[NSNumber numberWithInt:AVAudioQualityHigh] forKey:AVEncoderAudioQualityKey];
    
    //存储录音文件
    recordUrl = [NSURL URLWithString:[NSTemporaryDirectory() stringByAppendingString:@"selfRecord.wav"]];
    
    //初始化
    self.recorder = [[AVAudioRecorder alloc] initWithURL:recordUrl settings:recordSetting error:nil];
    //开启音量检测
    self.recorder.meteringEnabled = YES;
    _audioSession = [AVAudioSession sharedInstance];//得到AVAudioSession单例对象
    
    if (![self.recorder isRecording]) {
        [_audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];//设置类别,表示该应用同时支持播放和录音
        [_audioSession setActive:YES error:nil];//启动音频会话管理,此时会阻断后台音乐的播放.
        
        [self.recorder prepareToRecord];
        [self.recorder peakPowerForChannel:0.0];
        [self.recorder record];
    }
}

- (void)endRecord:(void(^)(NSData  *data))success{
    
    _callback = success;

    [self.recorder stop];                          //录音停止
  
    [_audioSession setActive:NO error:nil];         //一定要在录音停止以后再关闭音频会话管理（否则会报错），此时会延续后台音乐播放
    
    [self transformCAFToMP3];
}


- (void)transformCAFToMP3 {
    mp3FilePath = [NSURL URLWithString:[NSTemporaryDirectory() stringByAppendingString:@"myselfRecord.mp3"]];
    
    @try {
        int read, write;
        
        FILE *pcm = fopen([[recordUrl absoluteString] cStringUsingEncoding:1], "rb");   //source 被转换的音频文件位置
        fseek(pcm, 4*1024, SEEK_CUR);                                                   //skip file header
        FILE *mp3 = fopen([[mp3FilePath absoluteString] cStringUsingEncoding:1], "wb"); //output 输出生成的Mp3文件位置
        
        const int PCM_SIZE = 8192;
        const int MP3_SIZE = 8192;
        short int pcm_buffer[PCM_SIZE*2];
        unsigned char mp3_buffer[MP3_SIZE];
        
        lame_t lame = lame_init();
        lame_set_in_samplerate(lame, 11025.0);
        lame_set_VBR(lame, vbr_default);
        lame_init_params(lame);
        
        do {
            read = (int)fread(pcm_buffer, 2*sizeof(short int), PCM_SIZE, pcm);
            if (read == 0)
                write = lame_encode_flush(lame, mp3_buffer, MP3_SIZE);
            else
                write = lame_encode_buffer_interleaved(lame, pcm_buffer, read, mp3_buffer, MP3_SIZE);
            
            fwrite(mp3_buffer, write, 1, mp3);
            
        } while (read != 0);
        
        lame_close(lame);
        fclose(mp3);
        fclose(pcm);
    }
    @catch (NSException *exception) {
        NSLog(@"%@",[exception description]);
    }
    @finally {
        NSLog(@"MP3生成成功");
        
        NSData *mp3Data = [NSData dataWithContentsOfFile:[NSTemporaryDirectory() stringByAppendingString:@"myselfRecord.mp3"]];
        
        BLOCK_EXEC(_callback,mp3Data)
    }
}


- (NSString *)mp3ToBASE64{

    NSData *mp3Data = [NSData dataWithContentsOfFile:[NSTemporaryDirectory() stringByAppendingString:@"myselfRecord.mp3"]];
 
    NSString *_encodedImageStr = [mp3Data base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];

    NSLog(@"===Encoded image:\n%@", _encodedImageStr);

    return _encodedImageStr;
}





//开始播放音频文件
- (void)playMp3{
    //获取音频文件url
    //   NSURL * url = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:@"recordAudio.wav"]];
    //获取录音数据
    NSData * mp3Data = [NSData dataWithContentsOfFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"myselfRecord.mp3"]];
    NSError * error;
    //    AVAudioPlayer * player = [[AVAudioPlayer alloc]initWithContentsOfURL:url error:&error];
    _audioPlayer = [[AVAudioPlayer alloc]initWithData:mp3Data error:&error];
    _audioPlayer.delegate = self;
    if (error) {
        NSLog(@"语音播放失败,%@",error);
        return;
    }
    //播放器的声音会自动切到receiver，所以听起来特别小，如果需要从speaker出声，需要自己设置。
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
    // 单独设置音乐的音量（默认1.0，可设置范围为0.0至1.0，两个极端为静音、系统音量）：
    _audioPlayer.volume = 1.0;
    //    修改左右声道的平衡（默认0.0，可设置范围为-1.0至1.0，两个极端分别为只有左声道、只有右声道）：
    _audioPlayer.pan = -1;
    //    设置播放速度（默认1.0，可设置范围为0.5至2.0，两个极端分别为一半速度、两倍速度）：
    _audioPlayer.rate = 2.0;
    //    设置循环播放（默认1，若设置值大于0，则为相应的循环次数，设置为-1可以实现无限循环）：
    _audioPlayer.numberOfLoops = 0;
    //    player.currentTime = 0;
    //调用prepareToPlay方法，这样可以提前获取需要的硬件支持，并加载音频到缓冲区。在调用play方法时，减少开始播放的延迟。
    [_audioPlayer prepareToPlay];
    //    开始播放音乐：
    [_audioPlayer play];
    
}
//播放完成代理
- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag{
    if (flag) {
        NSLog(@"停止播放");
        //调用pause或stop来暂停播放，这里的stop方法的效果也只是暂停播放，不同之处是stop会撤销prepareToPlay方法所做的准备。
        [_audioPlayer stop];
        _audioPlayer = nil;
    }
}





@end
