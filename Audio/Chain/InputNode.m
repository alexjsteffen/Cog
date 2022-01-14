//
//  InputNode.m
//  Cog
//
//  Created by Vincent Spader on 8/2/05.
//  Copyright 2005 Vincent Spader. All rights reserved.
//

#import "InputNode.h"
#import "BufferChain.h"
#import "Plugin.h"
#import "CoreAudioUtils.h"
#import "AudioPlayer.h"
#import "OutputNode.h"


#import "Logging.h"

@implementation InputNode
@synthesize exitAtTheEndOfTheStream;


- (id)initWithController:(id)c previous:(id)p {
    self = [super initWithController:c previous:p];
    if (self) {
        exitAtTheEndOfTheStream = [[Semaphore alloc] init];
    }

    return self;
}


- (BOOL)openWithSource:(id<CogSource>)source
{
	decoder = [AudioDecoder audioDecoderForSource:source];

	if (decoder == nil)
		return NO;

	[self registerObservers];

	if (![decoder open:source])
	{
		ALog(@"Couldn't open decoder...");
		return NO;
	}
	
	NSDictionary *properties = [decoder properties];
	int bitsPerSample = [[properties objectForKey:@"bitsPerSample"] intValue];
	int channels = [[properties objectForKey:@"channels"] intValue];
	
	bytesPerFrame = ((bitsPerSample + 7) / 8) * channels;
    
	shouldContinue = YES;
	shouldSeek = NO;

	return YES;
}

- (BOOL)openWithDecoder:(id<CogDecoder>) d
{
	DLog(@"Opening with old decoder: %@", d);
	decoder = d;

	NSDictionary *properties = [decoder properties];
	int bitsPerSample = [[properties objectForKey:@"bitsPerSample"] intValue];
	int channels = [[properties objectForKey:@"channels"] intValue];
	
	bytesPerFrame = ((bitsPerSample + 7) / 8) * channels;
    
	[self registerObservers];

	shouldContinue = YES;
	shouldSeek = NO;
	
	DLog(@"DONES: %@", decoder);
	return YES;
}


- (void)registerObservers
{
	DLog(@"REGISTERING OBSERVERS");
	[decoder addObserver:self
			  forKeyPath:@"properties" 
				 options:(NSKeyValueObservingOptionNew)
				 context:NULL];

	[decoder addObserver:self
			  forKeyPath:@"metadata" 
				 options:(NSKeyValueObservingOptionNew)
				 context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object 
                        change:(NSDictionary *)change
                       context:(void *)context
{
	DLog(@"SOMETHING CHANGED!");
	if ([keyPath isEqual:@"properties"]) {
        DLog(@"Input format changed");
        // Converter doesn't need resetting for this, as output format hasn't changed
        ConverterNode *converter = [[[controller controller] bufferChain] converter];
        AudioStreamBasicDescription newInputFormat = [[[controller controller] bufferChain] inputFormat];
        AudioStreamBasicDescription oldInputFormat = [converter inputFormat];
        if (memcmp(&oldInputFormat, &newInputFormat, sizeof(oldInputFormat)) != 0)
            [converter inputFormatDidChange:newInputFormat];
	}
	else if ([keyPath isEqual:@"metadata"]) {
		//Inform something of metadata change
	}
}

- (void)process
{
	int amountInBuffer = 0;
	void *inputBuffer = malloc(CHUNK_SIZE);
	
	BOOL shouldClose = YES;
    BOOL seekError = NO;
	
	while ([self shouldContinue] == YES && [self endOfStream] == NO)
	{
		if (shouldSeek == YES)
		{
            ConverterNode *converter = [[[controller controller] bufferChain] converter];
			DLog(@"SEEKING! Resetting Buffer");
            
            amountInBuffer = 0;
            // This resets the converter's buffer
            [self resetBuffer];
            [converter resetBuffer];
            [converter inputFormatDidChange:[[[controller controller] bufferChain] inputFormat]];

            DLog(@"Reset buffer!");

            DLog(@"SEEKING!");
            seekError = [decoder seek:seekFrame] < 0;
            
			shouldSeek = NO;
			DLog(@"Seeked! Resetting Buffer");
			initialBufferFilled = NO;
		}

		if (amountInBuffer < CHUNK_SIZE) {
			int framesToRead = (CHUNK_SIZE - amountInBuffer)/bytesPerFrame;
			int framesRead = [decoder readAudio:((char *)inputBuffer) + amountInBuffer frames:framesToRead];

            if (framesRead > 0 && !seekError)
            {
                amountInBuffer += (framesRead * bytesPerFrame);
                [self writeData:inputBuffer amount:amountInBuffer];
                amountInBuffer = 0;
            }
            else
			{
				if (initialBufferFilled == NO) {
					[controller initialBufferFilled:self];
				}
				
				DLog(@"End of stream? %@", [self properties]);

				endOfStream = YES;
				shouldClose = [controller endOfInputReached]; //Lets us know if we should keep going or not (occassionally, for track changes within a file)
				DLog(@"closing? is %i", shouldClose);

                // wait before exiting, as we might still get seeking request
                DLog("InputNode: Before wait")
                [exitAtTheEndOfTheStream waitIndefinitely];
                DLog("InputNode: After wait, should seek = %d", shouldSeek)
                if (shouldSeek)
                {
                    endOfStream = NO;
                    shouldClose = NO;
                    continue;
                }
                else
                {
                    break;
                }
			}
        }
	}

	if (shouldClose)
		[decoder close];

    free(inputBuffer);

    [exitAtTheEndOfTheStream signal];

    DLog("Input node thread stopping");
}

- (void)seek:(long)frame
{
	seekFrame = frame;
	shouldSeek = YES;
	DLog(@"Should seek!");
	[semaphore signal];

    if (endOfStream)
    {
        [exitAtTheEndOfTheStream signal];
    }
}

- (BOOL)setTrack:(NSURL *)track
{
	if ([decoder respondsToSelector:@selector(setTrack:)] && [decoder setTrack:track]) {
		DLog(@"SET TRACK!");
		
		return YES;
	}
	
	return NO;
}

- (void)removeObservers
{
    [decoder removeObserver:self forKeyPath:@"properties"];
    [decoder removeObserver:self forKeyPath:@"metadata"];
}

- (void)dealloc
{
	DLog(@"Input Node dealloc");
    [self removeObservers];
}

- (NSDictionary *) properties
{
	return [decoder properties];
}

- (id<CogDecoder>) decoder
{
	return decoder;
}

- (double) secondsBuffered
{
    AudioStreamBasicDescription inputFormat = [[[controller controller] bufferChain] inputFormat];
    return ((double)[buffer bufferedLength] / (inputFormat.mSampleRate * inputFormat.mBytesPerPacket));
}

@end
