//
//  AppDelegate.m
//  MCAudioFileStream
//
//  Created by Chengyin on 14-7-12.
//  Copyright (c) 2014年 Chengyin. All rights reserved.
//

#import "AppDelegate.h"
#import "MCAudioFileStream.h"

@interface AppDelegate ()<MCAudioFileStreamDelegate>
{
@private
    MCAudioFileStream *_audioFileStream;
}
@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.rootViewController = [UIViewController new];
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"MP3Sample" ofType:@"mp3"];
    NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:path];
    unsigned long long fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] fileSize];
    NSError *error = nil;
    _audioFileStream = [[MCAudioFileStream alloc] initWithFileType:kAudioFileMP3Type fileSize:fileSize error:&error];
    _audioFileStream.delegate = self;
    if (error)
    {
        _audioFileStream = nil;
        NSLog(@"create audio file stream failed, error: %@",[error description]);
    }
    else
    {
        NSLog(@"audio file opened.");
        if (file)
        {
            NSUInteger lengthPerRead = 10000;
            while (fileSize > 0)
            {
                NSData *data = [file readDataOfLength:lengthPerRead];
                fileSize -= [data length];
                [_audioFileStream parseData:data error:&error];
                if (error)
                {
                    if (error.code == kAudioFileStreamError_NotOptimized)
                    {
                        NSLog(@"audio not optimized.");
                    }
                    break;
                }
            }
            NSLog(@"audio format: bitrate = %zd, duration = %lf.",_audioFileStream.bitRate,_audioFileStream.duration);
            [_audioFileStream close];
            _audioFileStream = nil;
            NSLog(@"audio file closed.");
            [file closeFile];
        }
    }
    
    return YES;
}

- (void)audioFileStreamReadyToProducePackets:(MCAudioFileStream *)audioFileStream
{
    NSLog(@"audio ready to produce packets.");
}

- (void)audioFileStream:(MCAudioFileStream *)audioFileStream audioDataParsed:(NSArray *)audioData
{
    NSLog(@"data parsed, should be filled in buffer.");
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
