
#import "DKRecordManager.h"
#import <AVFoundation/AVFoundation.h>

#define RECORD_FILE_CACHE_NAME @"/RECORD_FILE_CACHE_NAME"
@interface DKRecordManager ()<AVAudioRecorderDelegate>
/// 录音时长
@property (assign, nonatomic) NSInteger currentRecordTime;
/// 录音最大时长
@property (assign, nonatomic) NSInteger maxRecordTime;
/// 录音最小时长 0 无限制
@property (assign, nonatomic) NSInteger minRecordTime;
/// 录音时长定时器
@property (strong, nonatomic) dispatch_source_t waitingTimer;
/// 录音音量监测定时器
@property (strong, nonatomic) dispatch_source_t meterTimer;
/// 录音对象
@property (strong, nonatomic) AVAudioRecorder *recorder;
/// 录音参数集
@property (strong, nonatomic) NSMutableDictionary *recorderParamsDictionary;
/// 录音格式 format kAudioFormatMPEG4AAC
@property (assign, nonatomic) AudioFormatID audioFormatID;
/// 监听时间是否结束
@property (assign, nonatomic) BOOL timeout;
/// 是否监听l音量
@property (assign, nonatomic) BOOL meter;
@property (assign, nonatomic) BOOL isCancel;
@end

@implementation DKRecordManager

+ (DKRecordManager *)sharedManager {
    static DKRecordManager *sharedManager = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        sharedManager = [[DKRecordManager alloc] init];
    });
    return sharedManager;
}

#pragma mark --
#pragma mark -- PRIVATE 录音区

/// 必须先设置参数
- (BOOL)createRecorder {
    if (!_recorder) {
        if (!_recorderParamsDictionary) {
            return NO;
        }
        NSError *error;
        _recorder = [[AVAudioRecorder alloc] initWithURL:[self fileURL]
                                                settings:self.recorderParamsDictionary
                                                   error:&error];
        _recorder.delegate = self;
        [_recorder prepareToRecord];
        if (!error) {
            return YES;
        }else {
            return NO;
        }
    }
    return YES;
}
/// 删除录音recorder
- (void)removeRecorder {
    [_recorder stop];
    _recorder = nil;
    _recorderParamsDictionary = nil;
    [self removeRecordFile];
}
/// 开始录音
- (void)startRecorder {
    self.isCancel = NO;
    if (self.recorder == nil) {
        return;
    }
    
    // 音量
    self.recorder.meteringEnabled = self.meter;
    if (self.meter) {
        [self startMeterTime];
    }
    
    // 录音时长
    self.currentRecordTime = 0;
    
    // 录音
    NSError *error;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    [audioSession setActive:YES error:nil];
    if (!error) {
        self.timeout = NO;
        [self.recorder record];
        [self startTime];
    }else {
        NSLog(@"无法录音");
    }
}
/// 结束录音
- (void)stopRecorder {
    [self.recorder stop];
    [self stopTimer];
    [self stopMeterTimer];
}
/// 移除录音文件
- (BOOL)removeRecordFile  {
    [self.recorder stop];
    return [self.recorder deleteRecording];
}
/// 获取录音文件
- (NSURL *)getFileURL {
    return [self fileURL];
}
/// 移除代理
- (void)removeDelegate {
    self.delegate = nil;
}
/// 监测音量
- (void)meterTimerMethod {
    if (!self.recorder.meteringEnabled) {
        return;
    }
    // 更新测量值
    [self.recorder updateMeters];
    // 取得第一个通道的音频，注意音频强度范围时-160到0
    float power = [self.recorder averagePowerForChannel:0];
    CGFloat progress = (1.0 / 160.0) * (power + 160.0);
    NSLog(@"meterTimerMethod == %.2f",progress);
}
/// 取消
- (void)cancelRecorder {
    self.isCancel = YES;
    [self stopRecorder];
}

#pragma mark --
#pragma mark -- PRIVATE 参数设置区

/// 音量检测
/// @param able able
- (void)setMeteringEnable:(BOOL)able {
    self.meter = able;
}
- (void)setMaxRecordTime:(NSInteger)maxRecordTime {
    if (maxRecordTime == 0) {
        _maxRecordTime = INTMAX_MAX;
    }else if (time < 0) {
        _maxRecordTime = -1;
        NSLog(@"无效时间");
    }else {
        _maxRecordTime = maxRecordTime;
    }
}
- (void)setMinRecordTime:(NSInteger)time {
    if (time == 0) {
        _minRecordTime = INTMAX_MIN;
    }else if (time < 0) {
        _minRecordTime = -1;
        NSLog(@"无效时间");
    }else {
        _minRecordTime = time;
    }
}
// 设置录音格式 @(kAudioFormatMPEG4AAC)
- (void)setObjectFormat:(NSObject *)format // 设置录音格式 @(kAudioFormatMPEG4AAC)
                   rate:(NSObject *)rate // 设置录音采样率，8000是电话采样率 @(8000)
                channel:(NSObject *)channel // 设置通道 @(1)
      linearPCMBitDepth:(NSObject *)linearPCMBitDepth // 每个采样点位数 @(8)
        linearPCMIsFloat:(NSObject *)linearPCMIsFloat /*是否使用浮点数采样 @(YES)*/ {
    //设置录音格式
    [self.recorderParamsDictionary setObject:format forKey:AVFormatIDKey];
    self.audioFormatID = (AudioFormatID)[[NSString stringWithFormat:@"%@",format] intValue];
    //设置录音采样率，8000是电话采样率，对于一般录音已经够了
    [self.recorderParamsDictionary setObject:rate forKey:AVSampleRateKey];
    //设置通道,这里采用单声道
    [self.recorderParamsDictionary setObject:channel forKey:AVNumberOfChannelsKey];
    //每个采样点位数,分为8、16、24、32
    [self.recorderParamsDictionary setObject:linearPCMBitDepth forKey:AVLinearPCMBitDepthKey];
    //是否使用浮点数采样
    [self.recorderParamsDictionary setObject:linearPCMIsFloat forKey:AVLinearPCMIsFloatKey];
}
- (NSMutableDictionary *)recorderParamsDictionary {
    if (!_recorderParamsDictionary) {
        _recorderParamsDictionary = [NSMutableDictionary dictionaryWithCapacity:0];
    }
    return _recorderParamsDictionary;
}

#pragma mark --
#pragma mark -- PRIVATE 地址相关处理

+ (NSString *)cacheDictionary {
    NSString *cacheDictionary = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSLog(@"cacheDictionary -- %@",cacheDictionary);
    return cacheDictionary;
}
- (NSString *)appendFileName {
    NSString *address;
    if (self.audioFormatID == kAudioFormatMPEG4AAC) {
        address = @"aac";
    }
    NSString *appendFileName = [NSString stringWithFormat:@"%@%@.%@",[DKRecordManager cacheDictionary],RECORD_FILE_CACHE_NAME,address];
    return appendFileName;
}
- (NSURL *)fileURL {
    NSURL *url = [NSURL URLWithString:[self appendFileName]];
    return url;
}

#pragma mark --
#pragma mark -- PRIVATE 权限判断

/// 获取权限
+ (DKRecordManagerAudioAuthStatus)getAudioAuth {
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    switch (authStatus) {
        case AVAuthorizationStatusNotDetermined:
        // 被拒绝
        {
            return DKRecordManagerAudioAuthStatusNoAuth;
        }
        break;
        case AVAuthorizationStatusRestricted:
        // 未授权，家长限制
        {
            return DKRecordManagerAudioAuthStatusNoAuth;
        }
        break;
        case AVAuthorizationStatusDenied:
        // 玩家未授权
        {
            return DKRecordManagerAudioAuthStatusUnknow;
        }
        break;
        case AVAuthorizationStatusAuthorized:
        // 玩家授权
        {
            return DKRecordManagerAudioAuthStatusAuth;
        }
        break;
        default:
            return DKRecordManagerAudioAuthStatusUnknow;
        break;
    }
}

#pragma mark --
#pragma mark -- PRIVATE 定时器相关

- (void)startTime {
    if (self.maxRecordTime == 0) {
        return;
    }
    [self stopTimer];
    __block DKRecordManager *weakSelf = self;
    __block NSInteger time = 0;
    NSInteger timeSpace = 1;
    dispatch_queue_t queue = dispatch_get_main_queue();
    self.waitingTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_time_t start = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC));
    uint64_t interval = (uint64_t)(timeSpace * NSEC_PER_SEC);
    dispatch_source_set_timer(self.waitingTimer, start, interval, 0);
    dispatch_source_set_event_handler(self.waitingTimer, ^{
        // do something
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakSelf.maxRecordTime == 0) {
                // 时间未到，继续录音
                
                NSLog(@"录音时间 == %ld",time);
            }else {
                if (time > weakSelf.maxRecordTime) {
                    weakSelf.timeout = YES;
                    // 录音时间到
                    
                    weakSelf.isCancel = YES;
                    [weakSelf stopRecorder];
                }else {
                    // 时间未到，继续录音
                    
                    NSLog(@"录音时间 == %ld",time);
                }
            }
        });
        time ++;
        weakSelf.currentRecordTime = time;
    });
    dispatch_resume(self.waitingTimer);
}
- (void)stopTimer {
    if (_waitingTimer) {
        dispatch_cancel(_waitingTimer);
        _waitingTimer = nil;
    }
}
- (void)startMeterTime {
    [self stopMeterTimer];
    __block DKRecordManager *weakSelf = self;
    CGFloat timeSpace = 0.1;
    dispatch_queue_t queue = dispatch_get_main_queue();
    self.meterTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
    dispatch_time_t start = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC));
    uint64_t interval = (uint64_t)(timeSpace * NSEC_PER_SEC);
    dispatch_source_set_timer(self.meterTimer, start, interval, 0);
    dispatch_source_set_event_handler(self.meterTimer, ^{
        // do something
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf meterTimerMethod];
        });
    });
    dispatch_resume(self.meterTimer);
}
- (void)stopMeterTimer {
    if (_meterTimer) {
        dispatch_cancel(_meterTimer);
        _meterTimer = nil;
    }
}

#pragma mark --
#pragma mark -- DELEGATE <AVAudioRecorderDelegate>

- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    
}
- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError * __nullable)error {
    
}

@end
