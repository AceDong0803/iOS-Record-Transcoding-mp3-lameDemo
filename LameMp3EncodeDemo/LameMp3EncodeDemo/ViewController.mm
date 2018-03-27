//
//  ViewController.m
//  LameMp3EncodeDemo
//
//  Created by AnDong on 2018/2/13.
//  Copyright © 2018年 AnDong. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#include "mp3Encoder.hpp"
#import "Mp3FileModel.h"
#import "AudioPlayViewController.h"


//编码队列
static dispatch_queue_t mp3EncodeQueue() {
    static dispatch_queue_t cmdRequestQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cmdRequestQueue =
        dispatch_queue_create("mp3EncodeQueue", DISPATCH_QUEUE_SERIAL);
    });
    return cmdRequestQueue;
}

static dispatch_queue_t localMp3EncodeQueue() {
    static dispatch_queue_t cmdRequestQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        cmdRequestQueue =
        dispatch_queue_create("localMp3EncodeQueue", DISPATCH_QUEUE_SERIAL);
    });
    return cmdRequestQueue;
}

static NSString *const MP3SaveFilePath = @"MP3File";
static NSString *const CellReus = @"mp3Cell";


//采样率 44.1khz
#define sampleRate 44100
#define kSCREEN_WIDTH    [[UIScreen mainScreen] bounds].size.width
#define kSCREEN_HEIGHT   [UIScreen mainScreen].bounds.size.height


//边录制边编码的编码器
Mp3Encoder *streamEncoder = new Mp3Encoder();


@interface ViewController ()<AVAudioRecorderDelegate,UITableViewDelegate,UITableViewDataSource>
@property (nonatomic,strong) AVAudioRecorder *audioRecorder;
@property (nonatomic,strong) NSString *mp3Path;
@property (nonatomic,strong) NSString *cafPath;

@property (nonatomic,strong)UIButton *recordBtn;
@property (nonatomic,strong)UILabel *recordTimeLabel;
@property (nonatomic,strong)UITableView *localMp3TableView;
@property (nonatomic,strong)NSTimer *recordTimer;
@property (nonatomic,assign)NSInteger totalRecordSeconds;
//DataSource
@property (nonatomic,strong)NSMutableArray *mp3FileModelArray;
@end


@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _totalRecordSeconds = 0;
    
    //创建保存Mp3文件夹
    [self createMp3Folder];
    
    [self setupUI];
    
    //加载本地Mp3数据源
    [self getMp3DataSource];
    
    //异步转换本地PCM文件
    dispatch_async(localMp3EncodeQueue(), ^{
//        [self testLocalPCMToMp3];
    });

}

- (void)dealloc{
    if (streamEncoder) {
        delete streamEncoder;
    }
}

- (void)setupUI{
    [self.view addSubview:self.recordBtn];
    [self.view addSubview:self.recordTimeLabel];
    [self.view addSubview:self.localMp3TableView];
}

#pragma mark - 转换PCM本地文件到MP3

- (void)testLocalPCMToMp3{
    
    //获取原PCM路径 需要PCM，自己放一段，或者在我的blog网盘上面获取下载Demo PCM
    NSString *pcmPath = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"pcm"];
    
    //输出目标MP3路径
    NSString *mp3Path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:[NSString stringWithFormat:@"%@/LoacalTest.mp3",MP3SaveFilePath]];
    
    NSLog(@"%@",mp3Path);
    
    //编码Mp3  sampleRate使用标准Mp3 44.1khz 双声道 码率使用128kb
    Mp3Encoder encode;
    encode.Init([pcmPath cStringUsingEncoding:NSUTF8StringEncoding], [mp3Path cStringUsingEncoding:NSUTF8StringEncoding], 44100, 2, 128);
    
    //开始编码
    encode.EncodeLocalFile();
    
    //释放资源
    encode.Destroy();
    
    //主线程刷新数据
    dispatch_async(dispatch_get_main_queue(), ^{
        [self getMp3DataSource];
    });
}

#pragma mark - 获取本地Mp3数据源
- (void)getMp3DataSource{
    //先清空原来的数组
    [self.mp3FileModelArray removeAllObjects];

    NSString *folderPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)lastObject] stringByAppendingPathComponent:MP3SaveFilePath];
    
    //查找文件夹下的所有文件
    NSArray *tmplist = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folderPath error:nil];
    
    for (NSString *filename in tmplist) {
        if ([filename hasSuffix:@"mp3"]) {
            NSString *fullpath = [folderPath stringByAppendingPathComponent:filename];
            Mp3FileModel *model = [[Mp3FileModel alloc]init];
            model.mp3Path = fullpath;
            model.mp3Name = filename;
            [self.mp3FileModelArray addObject:model];
        }
    }
    [self.localMp3TableView reloadData];
}

#pragma mark - Event Handle
- (void)recordBtnAction{
    BOOL isSelect = self.recordBtn.selected;
    self.recordBtn.selected = !isSelect;
    if (isSelect) {
        //结束录音
        [self stopRecordTimer];
        [self recordEnd];
        [self.recordBtn setTitle:@"开始录音" forState:UIControlStateNormal];
    }
    else{
        //开始录音
        [self startRecordTimer];
        [self recordStart];
        [self.recordBtn setTitle:@"结束" forState:UIControlStateNormal];
    }
}

- (void)recordTimerAction{
    self.recordTimeLabel.text = [self getFormatString:_totalRecordSeconds];
    _totalRecordSeconds += 1;
}

//开始录音
- (void)recordStart{
    //清除上一次文件
    [self clearCafFile];
    
    if (![self.audioRecorder isRecording]) {
        //开启会话
        AVAudioSession *session = [AVAudioSession sharedInstance];
        NSError *sessionError;
        [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&sessionError];
        if(sessionError){
            NSLog(@"Set Audio Seesion Error: %@", [sessionError description]);}
        else{
            [session setActive:YES error:nil];
        }
        //录音
        [self.audioRecorder record];
        
        //先生成存储的MP3路径
        NSString *mp3Path = [self getCurrentMp3FilePath];
        
        //最重要的一步，要开始进行边录制边转码Mp3
        dispatch_async(mp3EncodeQueue(), ^{
            streamEncoder->Init([self.cafPath cStringUsingEncoding:NSUTF8StringEncoding],[mp3Path cStringUsingEncoding:NSUTF8StringEncoding] , 44100, 2, 128);
            streamEncoder->EncodeStreamFile();
            streamEncoder->Destroy();
            
            //主线程刷新数据
            dispatch_async(dispatch_get_main_queue(), ^{
                [self getMp3DataSource];
            });
        });
    }
}

//结束录音
- (void)recordEnd{
    if ([self.audioRecorder isRecording]) {
        //停止录音
        [self.audioRecorder stop];
        
        //设置标志位，编码结束
        streamEncoder->encodeEnd = true;
    }
}


#pragma mark - AVAudioRecorderDelegate
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag {
    if (flag) {
        NSLog(@"录音");
    }
}

#pragma mark - UITableViewDelegate && DataSource

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 44.0f;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.mp3FileModelArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellReus];
    
    if (!cell) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellReus];
    }
    
    Mp3FileModel *model = self.mp3FileModelArray[indexPath.row];
    cell.textLabel.text = model.mp3Name;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    AudioPlayViewController *playVc = [[AudioPlayViewController alloc]init];
    playVc.fileModel = self.mp3FileModelArray[indexPath.row];
    [self presentViewController:playVc animated:YES completion:^{
        
    }];
}


#pragma mark - Private Methods
- (void)startRecordTimer{
    if (!self.recordTimer) {
        self.recordTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(recordTimerAction) userInfo:nil repeats:YES];
        [self.recordTimer setFireDate:[NSDate distantPast]];
    }
}

- (void)stopRecordTimer{
    if (self.recordTimer) {
        [self.recordTimer invalidate];
        self.recordTimer = nil;
        _totalRecordSeconds = 0;
        self.recordTimeLabel.text = @"00:00";
    }
}

- (NSString *)getFormatString:(NSInteger)totalSeconds {
    NSInteger seconds = totalSeconds % 60;
    NSInteger minutes = (totalSeconds / 60) % 60;
    NSInteger hours = totalSeconds / 3600;
    if (hours <= 0) {
        return [NSString stringWithFormat:@"%02ld:%02ld",(long)minutes, (long)seconds];
    }
    return [NSString stringWithFormat:@"%02ld:%02ld:%02ld",(long)hours, (long)minutes, (long)seconds];
}

/**
 创建Mp3保存路径文件夹
 */
- (void)createMp3Folder{
    NSString *path = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)lastObject] stringByAppendingPathComponent:MP3SaveFilePath];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL isDirExist = [fileManager fileExistsAtPath:path isDirectory:&isDir];
    if(!(isDirExist && isDir))
    {
        BOOL createFolderSuc = [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
        if(createFolderSuc){
            NSLog(@"创建Mp3保存路径成功");
        }
    }
}

/**
 下一次录音开始会清除上一次的Caf文件，这里不缓存录音源文件
 */
- (void)clearCafFile {
    if (self.cafPath) {
        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL isDir = FALSE;
        BOOL isDirExist = [fileManager fileExistsAtPath:self.cafPath isDirectory:&isDir];
        if (isDirExist) {
            [fileManager removeItemAtPath:self.cafPath error:nil];
            NSLog(@"清除上一次的Caf文件");
        }
    }
}

#pragma mark - Getter


/**
  用当前时间戳来生成mp3文件名路径
 */
- (NSString *)getCurrentMp3FilePath{
    NSString *folderPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)lastObject] stringByAppendingPathComponent:MP3SaveFilePath];
    NSString *mp3FileName = [NSString stringWithFormat:@"%@.mp3",[self getCurrentTimeString]];
    return [folderPath stringByAppendingPathComponent:mp3FileName];
}

/**
 获取当前时间戳字符串
 */
-(NSString*)getCurrentTimeString{
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"YYYY_MM_dd_HH_mm_ss"];
    NSDate *datenow = [NSDate date];
    NSString *currentTimeString = [formatter stringFromDate:datenow];
    return currentTimeString;
}

/**
 *  录音caf文件路径
 */
-(NSURL *)getCafPath{
    //  在Documents目录下创建一个名为FileData的文件夹
    NSString *folderPath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)lastObject] stringByAppendingPathComponent:MP3SaveFilePath];
    self.cafPath = [folderPath stringByAppendingPathComponent:@"record.caf"];
    NSURL *url=[NSURL fileURLWithPath:self.cafPath];
    return url;
}

/**
 *  AVAudioRecorder
 */
- (AVAudioRecorder *)audioRecorder{
    if (!_audioRecorder) {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        NSError *sessionError;
        [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&sessionError];
        if(sessionError){
            NSLog(@"Error creating session: %@", [sessionError description]);
        }
        else{
            [session setActive:YES error:nil];
        }
        
        //创建录音文件保存路径
        NSURL *url= [self getCafPath];
        //创建录音参数
        NSDictionary *setting = [self getAudioSetting];
        NSError *error=nil;
        _audioRecorder = [[AVAudioRecorder alloc]initWithURL:url settings:setting error:&error];
        _audioRecorder.delegate=self;
        _audioRecorder.meteringEnabled=YES;
        [_audioRecorder prepareToRecord];
        if (error) {
            NSLog(@"创建AVAudioRecorder Error：%@",error.localizedDescription);
            return nil;
        }
    }
    return _audioRecorder;
}

/**
 *  录音参数设置
 */
- (NSDictionary *)getAudioSetting{
    NSMutableDictionary *dicM = [NSMutableDictionary dictionary];
    [dicM setObject:@(kAudioFormatLinearPCM) forKey:AVFormatIDKey];
    [dicM setObject:@(sampleRate) forKey:AVSampleRateKey]; //44.1khz的采样率
    [dicM setObject:@(2) forKey:AVNumberOfChannelsKey];
    [dicM setObject:@(16) forKey:AVLinearPCMBitDepthKey]; //16bit的PCM数据
    [dicM setObject:[NSNumber numberWithInt:AVAudioQualityMax] forKey:AVEncoderAudioQualityKey];
    return dicM;
}

- (UIButton *)recordBtn{
    if (!_recordBtn) {
        _recordBtn = [[UIButton alloc]initWithFrame:CGRectMake((kSCREEN_WIDTH - 100)/2, 150, 100, 50)];
        _recordBtn.backgroundColor = [UIColor blueColor];
        _recordBtn.layer.cornerRadius = 5.0f;
        _recordBtn.layer.masksToBounds = YES;
        _recordBtn.selected = NO;
        [_recordBtn setTitle:@"开始录音" forState:UIControlStateNormal];
        [_recordBtn addTarget:self action:@selector(recordBtnAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return _recordBtn;
}

- (UILabel *)recordTimeLabel{
    if (!_recordTimeLabel) {
        _recordTimeLabel = [[UILabel alloc]initWithFrame: CGRectMake((kSCREEN_WIDTH - 150)/2, 75, 150, 50)];
        _recordTimeLabel.font = [UIFont systemFontOfSize:18.0f];
        _recordTimeLabel.text = @"00:00";
        _recordTimeLabel.textColor = [UIColor blackColor];
        _recordTimeLabel.textAlignment = NSTextAlignmentCenter;
    }
    return _recordTimeLabel;
}

- (UITableView *)localMp3TableView{
    if (!_localMp3TableView) {
        _localMp3TableView = [[UITableView alloc]initWithFrame:CGRectMake(0, 250,kSCREEN_WIDTH, kSCREEN_HEIGHT - 250) style:UITableViewStylePlain];
        _localMp3TableView.dataSource = self;
        _localMp3TableView.delegate = self;
    }
    return _localMp3TableView;
}

- (NSMutableArray *)mp3FileModelArray{
    if (!_mp3FileModelArray) {
        _mp3FileModelArray = [NSMutableArray array];
    }
    return _mp3FileModelArray;
}

@end
