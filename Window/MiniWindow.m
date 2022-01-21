//
//  MiniWindow.m
//  Cog
//
//  Created by Vincent Spader on 2/22/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "MiniWindow.h"

#import <Carbon/Carbon.h>

@implementation MiniWindow

- (id)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)windowStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)deferCreation
{
    self = [super initWithContentRect:contentRect styleMask:windowStyle backing:bufferingType defer:deferCreation];
    if (self)
    {
        [self setShowsResizeIndicator:NO];
        [self setExcludedFromWindowsMenu:YES];
        [[self standardWindowButton:NSWindowZoomButton] setEnabled:NO];

        // Disallow height resize.
        [self setContentMinSize:NSMakeSize(325, 1)];
        [self setContentMaxSize:NSMakeSize(CGFLOAT_MAX, 1)];
        [self setCollectionBehavior:NSWindowCollectionBehaviorFullScreenAuxiliary];

        hdcdLogo = [NSImage imageNamed:@"hdcdLogoTemplate"];
    }

    return self;
}

- (void)awakeFromNib
{
    [self showHDCDLogo:NO];
}

- (void)toggleToolbarShown:(id)sender {
    // Mini window IS the toolbar, no point in hiding it.
    // Do nothing!
}

- (void)keyDown:(NSEvent *)event {
    BOOL modifiersUsed =([event modifierFlags] & (NSEventModifierFlagShift |
                                                  NSEventModifierFlagControl |
                                                  NSEventModifierFlagOption |
                                                  NSEventModifierFlagCommand)) ? YES : NO;
    if (modifiersUsed) {
        [super keyDown:event];
        return;
    }

    switch ([event keyCode]) {
        case kVK_Space:
            [playbackController playPauseResume:self];
            break;

        case kVK_Return:
            [playbackController play:self];
            break;

        case kVK_LeftArrow:
            [playbackController eventSeekBackward:self];
            break;

        case kVK_RightArrow:
            [playbackController eventSeekForward:self];
            break;

        case kVK_UpArrow:
            [playbackController volumeUp:self];
            break;

        case kVK_DownArrow:
            [playbackController volumeDown:self];
            break;

        default:
            [super keyDown:event];
            break;
    }
}

- (void)showHDCDLogo:(BOOL)show
{
    for (NSToolbarItem * toolbarItem in [miniToolbar items])
    {
        if ([[toolbarItem itemIdentifier] isEqualToString:@"hdcd"]) {
            if (show)
                [toolbarItem setImage:hdcdLogo];
            else
                [toolbarItem setImage:nil];
        }
    }
}

@end
