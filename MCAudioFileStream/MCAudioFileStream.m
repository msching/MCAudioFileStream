//
//  MCAudioFileStream.m
//  MCAudioFileStream
//
//  Created by Chengyin on 14-7-12.
//  Copyright (c) 2014年 Chengyin. All rights reserved.
//  https://github.com/msching/MCAudioFileStream

#import "MCAudioFileStream.h"

@interface MCAudioFileStream ()
{
@private
    BOOL _discontinuous;
    
    AudioFileStreamID _audioFileStreamID;
    
    SInt64 _dataOffset;
    UInt64 _audioDataByteCount;
    NSTimeInterval _packetDuration;
}
- (void)handleAudioFileStreamProperty:(AudioFileStreamPropertyID)propertyID;
- (void)handleAudioFileStreamPackets:(const void *)packets
                       numberOfBytes:(UInt32)numberOfBytes
                     numberOfPackets:(UInt32)numberOfPackets
                  packetDescriptions:(AudioStreamPacketDescription *)packetDescriptioins;
@end

#pragma mark - static callbacks
static void MCSAudioFileStreamPropertyListener(void *inClientData,
                                               AudioFileStreamID inAudioFileStream,
                                               AudioFileStreamPropertyID inPropertyID,
                                               UInt32 *ioFlags)
{
    __unsafe_unretained MCAudioFileStream *audioFileStream = (__bridge MCAudioFileStream *)inClientData;
    [audioFileStream handleAudioFileStreamProperty:inPropertyID];
}

static void MCAudioFileStreamPacketsCallBack(void *inClientData,
                                             UInt32 inNumberBytes,
                                             UInt32 inNumberPackets,
                                             const void *inInputData,
                                             AudioStreamPacketDescription *inPacketDescriptions)
{
    __unsafe_unretained MCAudioFileStream *audioFileStream = (__bridge MCAudioFileStream *)inClientData;
    [audioFileStream handleAudioFileStreamPackets:inInputData
                                    numberOfBytes:inNumberBytes
                                  numberOfPackets:inNumberPackets
                               packetDescriptions:inPacketDescriptions];
}

#pragma mark -
@implementation MCAudioFileStream
@synthesize fileType = _fileType;
@synthesize readyToProducePackets = _readyToProducePackets;
@dynamic available;
@synthesize delegate = _delegate;
@synthesize duration = _duration;
@synthesize bitRate = _bitRate;
@synthesize format = _format;
@synthesize maxPacketSize = _maxPacketSize;

#pragma init & dealloc
- (instancetype)initWithFileType:(AudioFileTypeID)fileType error:(NSError *__autoreleasing *)error
{
    self  = [super init];
    if (self)
    {
        _discontinuous = NO;
        _fileType = fileType;
        [self _openAudioFileStreamWithFileTypeHint:_fileType error:error];
    }
    return self;
}

- (void)dealloc
{
    [self _closeAudioFileStream];
}

- (NSError *)_errorForOSStatus:(OSStatus)status
{
    if (status != noErr)
    {
        return [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
    }
    return nil;
}

#pragma mark - open & close
- (BOOL)_openAudioFileStreamWithFileTypeHint:(AudioFileTypeID)fileTypeHint error:(NSError *__autoreleasing *)error
{
    OSStatus status = AudioFileStreamOpen((__bridge void *)self,
                                          MCSAudioFileStreamPropertyListener,
                                          MCAudioFileStreamPacketsCallBack,
                                          fileTypeHint,
                                          &_audioFileStreamID);
    
    if (status != noErr)
    {
        _audioFileStreamID = NULL;
    }
    *error = [self _errorForOSStatus:status];
    return status == noErr;
}

- (void)_closeAudioFileStream
{
    if (self.available)
    {
        AudioFileStreamClose(_audioFileStreamID);
        _audioFileStreamID = NULL;
    }
}

- (void)close
{
    [self _closeAudioFileStream];
}

- (BOOL)available
{
    return _audioFileStreamID != NULL;
}

#pragma mark - actions
- (BOOL)parseData:(NSData *)data error:(NSError **)error
{
    OSStatus status = AudioFileStreamParseBytes(_audioFileStreamID,(UInt32)[data length],[data bytes],_discontinuous ? kAudioFileStreamParseFlag_Discontinuity : 0);
    *error = [self _errorForOSStatus:status];
    return status == noErr;
}

- (SInt64)seekToTime:(NSTimeInterval *)time
{
    _discontinuous = YES;
    SInt64 approximateSeekOffset = _dataOffset + (*time / _duration) * _audioDataByteCount;
    SInt64 seekToPacket = floor(*time / _packetDuration);
    SInt64 seekByteOffset;
    UInt32 ioFlags = 0;
    SInt64 outDataByteOffset;
    OSStatus status = AudioFileStreamSeek(_audioFileStreamID, seekToPacket, &outDataByteOffset, &ioFlags);
    if (status == noErr && !(ioFlags & kAudioFileStreamSeekFlag_OffsetIsEstimated))
    {
        *time -= ((seekByteOffset - _dataOffset) - outDataByteOffset) * 8.0 / _bitRate;
        seekByteOffset = outDataByteOffset + _dataOffset;
    }
    else
    {
        seekByteOffset = approximateSeekOffset;
    }
    return seekByteOffset;
}

#pragma mark - callbacks
- (void)calculateDuration
{
    if (_audioDataByteCount > 0 && _bitRate > 0)
    {
        _duration = (_audioDataByteCount * 8) / _bitRate;
    }
}

- (void)calculatepPacketDuration
{
    if (_format.mSampleRate > 0)
    {
        _packetDuration = _format.mFramesPerPacket / _format.mSampleRate;
    }
}

- (void)handleAudioFileStreamProperty:(AudioFileStreamPropertyID)propertyID
{
    if (propertyID == kAudioFileStreamProperty_ReadyToProducePackets)
    {
        _readyToProducePackets = YES;
        _discontinuous = YES;
        
        UInt32 sizeOfUInt32 = sizeof(_maxPacketSize);
        OSStatus status = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_PacketSizeUpperBound, &sizeOfUInt32, &_maxPacketSize);
        if (status != noErr || _maxPacketSize == 0)
        {
            status = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_MaximumPacketSize, &sizeOfUInt32, &_maxPacketSize);
        }
        
        [_delegate audioFileStreamReadyToProducePackets:self];
    }
    else if (propertyID == kAudioFileStreamProperty_BitRate)
    {
        UInt32 bitRateSize = sizeof(_bitRate);
        AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_BitRate, &bitRateSize, &_bitRate);
        [self calculateDuration];
    }
    else if (propertyID == kAudioFileStreamProperty_DataOffset)
    {
        UInt32 offsetSize = sizeof(_dataOffset);
        AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_DataOffset, &offsetSize, &_dataOffset);
    }
    else if (propertyID == kAudioFileStreamProperty_AudioDataByteCount)
    {
        UInt32 byteCountSize = sizeof(_audioDataByteCount);
        AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_AudioDataByteCount, &byteCountSize, &_audioDataByteCount);
        [self calculateDuration];
    }
    else if (propertyID == kAudioFileStreamProperty_DataFormat)
    {
        UInt32 asbdSize = sizeof(_format);
        AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_DataFormat, &asbdSize, &_format);
        [self calculatepPacketDuration];
    }
    else if (propertyID == kAudioFileStreamProperty_FormatList)
    {
        Boolean outWriteable;
        UInt32 formatListSize;
        OSStatus status = AudioFileStreamGetPropertyInfo(_audioFileStreamID, kAudioFileStreamProperty_FormatList, &formatListSize, &outWriteable);
        if (status == noErr)
        {
            AudioFormatListItem *formatList = malloc(formatListSize);
            OSStatus status = AudioFileStreamGetProperty(_audioFileStreamID, kAudioFileStreamProperty_FormatList, &formatListSize, formatList);
            if (status == noErr)
            {
                UInt32 supportedFormatsSize;
                status = AudioFormatGetPropertyInfo(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportedFormatsSize);
                if (status != noErr)
                {
                    free(formatList);
                    return;
                }
                
                UInt32 supportedFormatCount = supportedFormatsSize / sizeof(OSType);
                OSType *supportedFormats = (OSType *)malloc(supportedFormatsSize);
                status = AudioFormatGetProperty(kAudioFormatProperty_DecodeFormatIDs, 0, NULL, &supportedFormatCount, supportedFormats);
                if (status != noErr)
                {
                    free(formatList);
                    free(supportedFormats);
                    return;
                }
                
                for (int i = 0; i * sizeof(AudioFormatListItem) < formatListSize; i += sizeof(AudioFormatListItem))
                {
                    AudioStreamBasicDescription format = formatList[i].mASBD;
                    for (UInt32 j = 0; j < supportedFormatCount; ++j)
                    {
                        if (format.mFormatID == supportedFormats[j])
                        {
                            _format = format;
                            [self calculatepPacketDuration];
                            break;
                        }
                    }
                }
                free(supportedFormats);
            }
            free(formatList);
        }
    }
}

- (void)handleAudioFileStreamPackets:(const void *)packets
                       numberOfBytes:(UInt32)numberOfBytes
                     numberOfPackets:(UInt32)numberOfPackets
                  packetDescriptions:(AudioStreamPacketDescription *)packetDescriptioins
{
    if (_discontinuous)
    {
        _discontinuous = NO;
    }
    
    if (numberOfBytes == 0 || numberOfPackets == 0)
    {
        return;
    }
    
    BOOL deletePackDesc = NO;
    if (packetDescriptioins == NULL)
    {
        deletePackDesc = YES;
        UInt32 packetSize = numberOfBytes / numberOfPackets;
        AudioStreamPacketDescription *descriptions = (AudioStreamPacketDescription *)malloc(sizeof(AudioStreamPacketDescription) * numberOfPackets);
        
        for (int i = 0; i < numberOfPackets; i++)
        {
            UInt32 packetOffset = packetSize * i;
            descriptions[i].mStartOffset = packetOffset;
            descriptions[i].mVariableFramesInPacket = 0;
            if (i == numberOfPackets - 1)
            {
                descriptions[i].mDataByteSize = numberOfBytes - packetOffset;
            }
            else
            {
                descriptions[i].mDataByteSize = packetSize;
            }
        }
        packetDescriptioins = descriptions;
    }
    
    NSMutableArray *parsedDataArray = [[NSMutableArray alloc] init];
    for (int i = 0; i < numberOfPackets; ++i)
    {
        SInt64 packetOffset = packetDescriptioins[i].mStartOffset;
        MCParsedAudioData *parsedData = [MCParsedAudioData parsedAudioDataWithBytes:packets + packetOffset
                                                                  packetDescription:packetDescriptioins[i]];
        
        [parsedDataArray addObject:parsedData];
    }
    
    [_delegate audioFileStream:self audioDataParsed:parsedDataArray];
    
    if (deletePackDesc)
    {
        free(packetDescriptioins);
    }
}
@end
