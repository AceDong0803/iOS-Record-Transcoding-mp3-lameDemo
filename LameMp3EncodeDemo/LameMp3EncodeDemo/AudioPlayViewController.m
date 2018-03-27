//
//  AudioPlayViewController.m
//  LameMp3EncodeDemo
//
//  Created by AnDong on 2018/3/15.
//  Copyright © 2018年 AnDong. All rights reserved.
//

#import "AudioPlayViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "Mp3FileModel.h"

@interface AudioPlayViewController ()<AVAudioPlayerDelegate>
@property (weak, nonatomic) IBOutlet UILabel *playTimeLabel;
@property (weak, nonatomic) IBOutlet UIButton *playBtn;
@property (nonatomic,strong) AVAudioPlayer *player;
@property (nonatomic,strong) NSTimer *playStatusTimer;
@end

@implementation AudioPlayViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.player = [[AVAudioPlayer alloc]initWithContentsOfURL:
                                       [NSURL URLWithString:self.fileModel.mp3Path]
                                       error:nil];
    self.player.delegate = self;
    //开始播放
    [self.player prepareToPlay];
    //播放
    [self.player play];
    
    [self startPlayStatusTimer];
}

- (void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [self.player stop];
    [self stopPlayStatusTimer];
}

- (IBAction)navBack:(UIButton *)sender {
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}

- (void)updateTime{
    NSTimeInterval currentTime = self.player.currentTime;
    self.playTimeLabel.text = [self getFormatString:currentTime];
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

- (void)startPlayStatusTimer{
    if (!self.playStatusTimer) {
        self.playStatusTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(updateTime) userInfo:nil repeats:YES];
        [self.playStatusTimer setFireDate:[NSDate distantPast]];
    }
}

- (void)stopPlayStatusTimer{
    if (self.playStatusTimer) {
        [self.playStatusTimer invalidate];
        self.playStatusTimer = nil;
        self.playTimeLabel.text = @"00:00";
    }
}

#pragma mark - AVAudioPlayerDelegate

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer*)player successfully:(BOOL)flag{
    //播放结束
    [self stopPlayStatusTimer];
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer*)player error:(NSError *)error{
    //解码错误
}

- (void)audioPlayerBeginInteruption:(AVAudioPlayer*)player{
    //处理中断
}

- (void)audioPlayerEndInteruption:(AVAudioPlayer*)player{
    //处理中断结束
}


- (IBAction)playBtnClick:(UIButton *)sender {
    //暂停播放
    sender.selected = !sender.selected;
    
    if (sender.selected) {
        //暂停
        [self.player pause];
        [sender setTitle:@"开始播放" forState:UIControlStateNormal];
    }
    else{
        //开始播放
        [self.player play];
        [sender setTitle:@"暂停" forState:UIControlStateNormal];
    }
}


@end
