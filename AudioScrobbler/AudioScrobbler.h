/*
 *  $Id: AudioScrobbler.h 238 2007-01-26 22:55:20Z stephen_booth $
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

#import <Cocoa/Cocoa.h>

#import <mach/mach.h>

@class PlaylistEntry;

@interface AudioScrobbler : NSObject {
	NSString *_pluginID;
	NSMutableArray *_queue;

	BOOL _audioScrobblerThreadCompleted;
	BOOL _keepProcessingAudioScrobblerCommands;
	semaphore_t _semaphore;
}

+ (BOOL)isRunning;

- (void)start:(PlaylistEntry *)pe;
- (void)stop;
- (void)pause;
- (void)resume;

- (void)shutdown;

@end
