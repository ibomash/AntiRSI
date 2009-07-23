/*
 author: Onne Gorter
 
 This file is part of AntiRSI.
 
 AntiRSI is free software; you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation; either version 2 of the License, or
 (at your option) any later version.
 
 AntiRSI is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with AntiRSI; if not, write to the Free Software
 Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

#import <Cocoa/Cocoa.h>
#import "AntiRSIView.h"

#define sLatestVersionURL @"http://tech.inhelsinki.nl/antirsi/antirsi_version.txt"
#define sURL @"http://tech.inhelsinki.nl/antirsi/"
#define sVersion @"1.4"

typedef enum _AntiRSIState {
	s_normal = 0,
	s_taking_micro_pause,
	s_taking_work_break,
} AntiRSIState;

@interface AntiRSI : NSObject
{
	// views to display current status in
	IBOutlet AntiRSIView *view;
	IBOutlet NSProgressIndicator *progress;
	IBOutlet NSButton *postpone;
	IBOutlet NSTextField *time;
	IBOutlet NSTextField *next_break;
	IBOutlet NSTextField *version;
	
	// images
	NSImage* micro_pause_image;
	NSImage* work_break_image;
	
	// dock icon image
	NSImage* dock_image;
	NSImage* original_dock_image;
	
	// window to display the views in
	NSWindow *main_window;
	
	// timer that ticks every second to update
	NSTimer *mtimer;
	
	// various timers
	double micro_pause_t;
	double work_break_t;
	double micro_pause_taking_t;
	double work_break_taking_t;
	double work_break_taking_cached_t;
	double work_break_taking_cached_date;
	double date;
		
	// various timing lengths
	int micro_pause_period;
	int micro_pause_duration;
	int work_break_period;
	int work_break_duration;
	
	double sample_interval;
	
	// verious other options
	bool lock_focus;
	bool draw_dock_image;
	bool draw_dock_image_q;
	
	// various colors
	NSColor* taking;
	NSColor* elapsed;
	NSColor* background;
	NSColor* darkbackground;
	
	// state we are in
	AntiRSIState state;
	
	// history filter
	double h0;
	double h1;
	double h2;
}

//bindings
- (void)setMicro_pause_duration:(float)f;
- (void)setMicro_pause_period:(float)f;
- (void)setWork_break_period:(float)f;
- (void)setWork_break_period:(float)f;
- (void)setSample_interval:(NSString *)s;
- (void)setDraw_dock_image:(BOOL)b;
- (void)setBackground:(NSColor *)c;

// goto website button
- (IBAction)gotoWebsite:(id)sender;

// check updates
- (IBAction)checkForUpdate:(id)sender;

// postpone button
- (IBAction)postpone:(id)sender;

// workbreak now menu item
- (IBAction)breakNow:(id)sender;

// one second ticks away ...
- (void)tick:(NSTimer *)timer;

// draw the dock icon
- (void)drawDockImage;

// run the micro pause window
- (void)doMicroPause;

// run the work break window
- (void)doWorkBreak;

// stop micro pause or work break
- (void)endBreak;

// time left string
- (void)drawTimeLeft:(int)seconds;

// time to next break string
- (void)drawNextBreak:(int)seconds;

@end



