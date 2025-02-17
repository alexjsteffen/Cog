/*
 *  $Id: AudioScrobbler.m 238 2007-01-26 22:55:20Z stephen_booth $
 *
 *  Copyright (C) 2006 - 2007 Stephen F. Booth <me@sbooth.org>
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#import "AudioScrobbler.h"

#import "AudioScrobblerClient.h"
#import "PlaylistEntry.h"

#import "Logging.h"

// ========================================
// Symbolic Constants
// ========================================
NSString *const AudioScrobblerRunLoopMode = @"org.cogx.Cog.AudioScrobbler.RunLoopMode";

// ========================================
// Helpers
// ========================================
static NSString *
escapeForLastFM(NSString *string) {
	NSMutableString *result = [string mutableCopy];

	[result replaceOccurrencesOfString:@"&"
	                        withString:@"&&"
	                           options:NSLiteralSearch
	                             range:NSMakeRange(0, [result length])];

	return (nil == result ? @"" : result);
}

@interface AudioScrobbler (Private)

- (NSMutableArray *)queue;
- (NSString *)pluginID;

- (void)sendCommand:(NSString *)command;

- (BOOL)keepProcessingAudioScrobblerCommands;
- (void)setKeepProcessingAudioScrobblerCommands:(BOOL)keepProcessingAudioScrobblerCommands;

- (BOOL)audioScrobblerThreadCompleted;
- (void)setAudioScrobblerThreadCompleted:(BOOL)audioScrobblerThreadCompleted;

- (semaphore_t)semaphore;

- (void)processAudioScrobblerCommands:(id)unused;

@end

@implementation AudioScrobbler

+ (BOOL)isRunning {
	NSArray *launchedApps = [[NSWorkspace sharedWorkspace] runningApplications];
	BOOL running = NO;
	for(NSRunningApplication *app in launchedApps) {
		if([[app bundleIdentifier] isEqualToString:@"fm.last.Last.fm"] ||
		   [[app bundleIdentifier] isEqualToString:@"fm.last.Scrobbler"]) {
			running = YES;
			break;
		}
	}
	return running;
}

- (id)init {
	if((self = [super init])) {
		_pluginID = @"cog";

		if([[NSUserDefaults standardUserDefaults] boolForKey:@"automaticallyLaunchLastFM"]) {
			if(![AudioScrobbler isRunning]) {
				[[NSWorkspace sharedWorkspace] launchApplication:@"Last.fm.app"];
			}
		}

		_keepProcessingAudioScrobblerCommands = YES;

		kern_return_t result = semaphore_create(mach_task_self(), &_semaphore, SYNC_POLICY_FIFO, 0);

		if(KERN_SUCCESS != result) {
			ALog(@"Couldn't create semaphore (%s).", mach_error_type(result));

			self = nil;
			return nil;
		}

		[NSThread detachNewThreadSelector:@selector(processAudioScrobblerCommands:) toTarget:self withObject:nil];
	}
	return self;
}

- (void)dealloc {
	if([self keepProcessingAudioScrobblerCommands] || NO == [self audioScrobblerThreadCompleted])
		[self shutdown];

	_queue = nil;

	semaphore_destroy(mach_task_self(), _semaphore);
	_semaphore = 0;
}

- (void)start:(PlaylistEntry *)pe {
	[self sendCommand:[NSString stringWithFormat:@"START c=%@&a=%@&t=%@&b=%@&m=%@&l=%i&p=%@\n",
	                                             [self pluginID],
	                                             escapeForLastFM([pe artist]),
	                                             escapeForLastFM([pe title]),
	                                             escapeForLastFM([pe album]),
	                                             @"", // TODO: MusicBrainz support
	                                             [[pe length] intValue],
	                                             escapeForLastFM([[pe URL] path])]];
}

- (void)stop {
	[self sendCommand:[NSString stringWithFormat:@"STOP c=%@\n", [self pluginID]]];
}

- (void)pause {
	[self sendCommand:[NSString stringWithFormat:@"PAUSE c=%@\n", [self pluginID]]];
}

- (void)resume {
	[self sendCommand:[NSString stringWithFormat:@"RESUME c=%@\n", [self pluginID]]];
}

- (void)shutdown {
	[self setKeepProcessingAudioScrobblerCommands:NO];
	semaphore_signal([self semaphore]);

	// Wait for the thread to terminate
	while(NO == [self audioScrobblerThreadCompleted])
		[[NSRunLoop currentRunLoop] runMode:AudioScrobblerRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.2]];
}

@end

@implementation AudioScrobbler (Private)

- (NSMutableArray *)queue {
	if(nil == _queue)
		_queue = [[NSMutableArray alloc] init];

	return _queue;
}

- (NSString *)pluginID {
	return _pluginID;
}

- (void)sendCommand:(NSString *)command {
	@synchronized([self queue]) {
		[[self queue] addObject:command];
	}
	semaphore_signal([self semaphore]);
}

- (BOOL)keepProcessingAudioScrobblerCommands {
	return _keepProcessingAudioScrobblerCommands;
}

- (void)setKeepProcessingAudioScrobblerCommands:(BOOL)keepProcessingAudioScrobblerCommands {
	_keepProcessingAudioScrobblerCommands = keepProcessingAudioScrobblerCommands;
}

- (BOOL)audioScrobblerThreadCompleted {
	return _audioScrobblerThreadCompleted;
}

- (void)setAudioScrobblerThreadCompleted:(BOOL)audioScrobblerThreadCompleted {
	_audioScrobblerThreadCompleted = audioScrobblerThreadCompleted;
}

- (semaphore_t)semaphore {
	return _semaphore;
}

- (void)processAudioScrobblerCommands:(id)unused {
	@autoreleasepool {
		AudioScrobblerClient *client = [[AudioScrobblerClient alloc] init];
		mach_timespec_t timeout = { 5, 0 };
		NSString *command = nil;
		NSString *response = nil;
		in_port_t port = 33367;

		while([self keepProcessingAudioScrobblerCommands]) {
			@autoreleasepool {
				// Get the first command to be sent
				@synchronized([self queue]) {
					if([[self queue] count]) {
						command = [[self queue] objectAtIndex:0];
						[[self queue] removeObjectAtIndex:0];
					}
				}

				if(nil != command) {
					@try {
						if([client connectToHost:@"localhost" port:port]) {
							port = [client connectedPort];
							[client send:command];
							command = nil;

							response = [client receive];
							if(2 > [response length] || NSOrderedSame != [response compare:@"OK" options:NSLiteralSearch range:NSMakeRange(0, 2)])
								ALog(@"AudioScrobbler error: %@", response);

							[client shutdown];
						}
					}

					@catch(NSException *exception) {
						command = nil;

						[client shutdown];
						//                      ALog(@"Exception: %@",exception);
						continue;
					}
				}

				semaphore_timedwait([self semaphore], timeout);
			}
		}

		// Send a final stop command to cleanup
		@try {
			if([client connectToHost:@"localhost" port:port]) {
				[client send:[NSString stringWithFormat:@"STOP c=%@\n", [self pluginID]]];

				response = [client receive];
				if(2 > [response length] || NSOrderedSame != [response compare:@"OK" options:NSLiteralSearch range:NSMakeRange(0, 2)])
					ALog(@"AudioScrobbler error: %@", response);

				[client shutdown];
			}
		}

		@catch(NSException *exception) {
			[client shutdown];
		}

		[self setAudioScrobblerThreadCompleted:YES];
	}
}

@end
