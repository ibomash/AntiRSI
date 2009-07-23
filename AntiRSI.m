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

#import "AntiRSI.h"

#include <math.h>

// reverse enginered object, might change in the future, but does work now ...
@interface ScreenSaverUserInfo:NSObject
{}
+ sharedInstance;
- (double)idleTime;
@end

@implementation AntiRSI

// bindings methods
- (void)setMicro_pause_duration:(float)f
{
	micro_pause_duration = round(f);
	if (s_taking_micro_pause == state) {
		[progress setMaxValue:micro_pause_duration];
		[progress setDoubleValue:micro_pause_taking_t];
	}
}

- (void)setMicro_pause_period:(float)f
{	micro_pause_period = 60 * round(f); }

- (void)setWork_break_duration:(float)f
{   
	work_break_duration = 60 * round(f); 
	if (s_taking_work_break == state) {
		[progress setMaxValue:work_break_duration];
		[progress setDoubleValue:work_break_taking_t];
	}
}

- (void)setWork_break_period:(float)f
{	work_break_period = 60 * round(f); }

- (void)installTimer:(double)interval
{
	if (mtimer != nil) {
		[mtimer invalidate];
		[mtimer autorelease];
	}
	mtimer = [[NSTimer scheduledTimerWithTimeInterval:interval target:self selector:@selector(tick:)
  											userInfo:nil repeats:YES] retain];
}

- (void)setSample_interval:(NSString *)s
{
	sample_interval = 1;
	if ([s isEqualToString:@"Super Smooth"]) sample_interval = 0.1;
	if ([s isEqualToString:@"Smooth"]) sample_interval = 0.33;
	if ([s isEqualToString:@"Normal"]) sample_interval = 1;
	if ([s isEqualToString:@"Low"]) sample_interval = 2;
	
	[self installTimer:sample_interval];
}

- (void)setDraw_dock_image:(BOOL)b 
{
	draw_dock_image=b;
	if (!b) {
		[NSApp setApplicationIconImage:[NSImage imageNamed:@"AntiRSI"]];
	} else {
		[self drawDockImage];
	}
}

- (void)setBackground:(NSColor *)c
{
	[background autorelease];
	background=[c retain];
	
	// make new darkbackground color
	float r,g,b,a;
	[background getRed:&r green:&g blue:&b alpha:&a];
	[darkbackground autorelease];
	darkbackground=[[NSColor colorWithCalibratedRed:r*0.35 green:g*0.35 blue:b*0.35 alpha:a+0.2] retain];
	
	[self drawDockImage];
}

- (void)setElapsed:(NSColor *)c
{
	[elapsed autorelease];
	elapsed=[c retain];
	[self drawDockImage];
}

- (void)setTaking:(NSColor *)c
{
	[taking autorelease];
	taking=[c retain];
	[self drawDockImage];
}

// end of bindings

- (void)awakeFromNib
{
	// want transparancy
	[NSColor setIgnoresAlpha:NO];
	
	// initial colors
	elapsed = [[NSColor colorWithCalibratedRed:0.3 green:0.3 blue:0.9 alpha:0.95] retain];
	taking = [[NSColor colorWithCalibratedRed:0.3 green:0.9 blue:0.3 alpha:0.90] retain];
	background = [NSColor colorWithCalibratedRed:0.9 green:0.9 blue:0.9 alpha:0.7];
	
	//initial values
	micro_pause_period = 4*60;
	micro_pause_duration = 13;
	work_break_period = 50*60;
	work_break_duration = 8*60;
	sample_interval = 1;
	
	// set current state
	state = s_normal;
	
	// set timers to 0
	micro_pause_t = 0;
	work_break_t = 0;
	micro_pause_taking_t = 0;
	work_break_taking_t = 0;
	work_break_taking_cached_t = 0;
	work_break_taking_cached_date = 0;
	
	// setup images
	micro_pause_image = [NSImage imageNamed:@"micro_pause"];
	work_break_image = [NSImage imageNamed:@"work_break"];

	// initialize dock image
	dock_image = [[NSImage alloc] initWithSize:NSMakeSize(128,128)];
	[dock_image setCacheMode:NSImageCacheNever];
	original_dock_image = [NSImage imageNamed:@"AntiRSI"];
	draw_dock_image_q = YES;
	
	// setup main window that will show either micropause or workbreak
	main_window = [[NSWindow alloc] initWithContentRect:[view frame]
											  styleMask:NSBorderlessWindowMask
												backing:NSBackingStoreBuffered defer:YES];
	[main_window setBackgroundColor:[NSColor clearColor]];
	[main_window setLevel:NSScreenSaverWindowLevel];
	[main_window setAlphaValue:0.85];
	[main_window setOpaque:NO];
	[main_window setHasShadow:NO];
	[main_window setMovableByWindowBackground:YES];
	[main_window center];
	[main_window setContentView:view];
	
	// initialze history filter
	h0 = 0;
	h1 = 0;
	h2 = 0;
	
	// initialize ticks
	date = [NSDate timeIntervalSinceReferenceDate];
	
	// set background now
	[self setBackground:background];
	
	// create initial values
	NSMutableDictionary* initial = [NSMutableDictionary dictionaryWithCapacity:10];
	[initial setObject:[NSNumber numberWithFloat:4] forKey:@"micro_pause_period"];
	[initial setObject:[NSNumber numberWithFloat:13] forKey:@"micro_pause_duration"];
	[initial setObject:[NSNumber numberWithFloat:50] forKey:@"work_break_period"];
	[initial setObject:[NSNumber numberWithFloat:8] forKey:@"work_break_duration"];
	[initial setObject:@"Smooth" forKey:@"sample_interval"];
	[initial setObject:[NSNumber numberWithBool:YES] forKey:@"draw_dock_image"];
	[initial setObject:[NSNumber numberWithBool:NO] forKey:@"lock_focus"];
	[initial setObject:[NSArchiver archivedDataWithRootObject:elapsed] forKey:@"elapsed"];
	[initial setObject:[NSArchiver archivedDataWithRootObject:taking] forKey:@"taking"];
	[initial setObject:[NSArchiver archivedDataWithRootObject:background] forKey:@"background"];
	[[NSUserDefaultsController sharedUserDefaultsController] setInitialValues:initial];

	// bind to defauls controller
	id dc = [NSUserDefaultsController sharedUserDefaultsController];
	[self bind:@"micro_pause_period" toObject:dc withKeyPath:@"values.micro_pause_period" options:nil];
	[self bind:@"micro_pause_duration" toObject:dc withKeyPath:@"values.micro_pause_duration" options:nil];
	[self bind:@"work_break_period" toObject:dc withKeyPath:@"values.work_break_period" options:nil];
	[self bind:@"work_break_duration" toObject:dc withKeyPath:@"values.work_break_duration" options:nil];
	[self bind:@"sample_interval" toObject:dc withKeyPath:@"values.sample_interval" options:nil];
	[self bind:@"draw_dock_image" toObject:dc withKeyPath:@"values.draw_dock_image" options:nil];
	[self bind:@"lock_focus" toObject:dc withKeyPath:@"values.lock_focus" options:nil];
	NSDictionary* unarchive = [NSDictionary dictionaryWithObject:NSUnarchiveFromDataTransformerName forKey:@"NSValueTransformerName"];
	[self bind:@"elapsed" toObject:dc withKeyPath:@"values.elapsed" options:unarchive];
	[self bind:@"taking" toObject:dc withKeyPath:@"values.taking" options:unarchive];
	[self bind:@"background" toObject:dc withKeyPath:@"values.background" options:unarchive];

	// alert every binding
	[[NSUserDefaultsController sharedUserDefaultsController] revert:self];

	// start the timer
	[self installTimer:sample_interval];
	
	// about dialog
	[version setStringValue:[NSString stringWithFormat:@"Version %@", sVersion]]; 
}

// tick every second and update status
- (void)tick:(NSTimer *)timer
{
	// calculate time since last tick
	double new_date = [NSDate timeIntervalSinceReferenceDate];
	double tick_time = new_date - date;
	date = new_date;
	
	// check if we are still on track of normal time, otherwise we might have slept or something
	if (tick_time > work_break_duration) {
		// set timers to 0
		micro_pause_t = 0;
		work_break_t = 0;
		micro_pause_taking_t = micro_pause_duration;
		work_break_taking_t = work_break_duration;
		if (s_normal != state) {
			[self endBreak];
		}
		// and do stuff on next tick
		return;
	}
	
	// just did a whole micropause beyond normal time
	if (tick_time > micro_pause_duration && s_taking_work_break != state) {
		// set micro_pause timers to 0
		micro_pause_t = 0;
		micro_pause_taking_t = micro_pause_duration;
		if (s_normal != state) {
			[self endBreak];
		}
		// and do stuff on next tick
		return;
	}
	
	// get idle time in seconds
	double idle_time = [[ScreenSaverUserInfo sharedInstance] idleTime];
	
	// calculate slack, this gives a sort of 4 history filtered idea. 
	// Prevents Media players from activating AntiRSI.
	BOOL slack = ((h2 + h1 + h0 + idle_time) > 15); //means: if last 4 measured idle_times are more then 15 seconds ...
	
	// if new event comes in history bumps up
	if (h0 >= idle_time) { //  || idle_time < sample_interval
		//NSLog(@"h2=%f, h1=%f, h0=%f, %f", h2, h1, h0, (h2 + h1 + h0 + idle_time));
		h2 = h1;
		h1 = h0;		
	}
	h0 = idle_time;
		
	switch (state) {
		case s_normal:
			// idle_time needs to be at least 0.3 * micro_pause_duration before kicking in
			// but we cut the user some slack based on previous idle_times
			if (idle_time <= micro_pause_duration * 0.3 && !slack) {
				micro_pause_t += tick_time;
				work_break_t += tick_time;
				micro_pause_taking_t = 0;
				if (work_break_taking_t > 0) {
					work_break_taking_cached_t = work_break_taking_t;
					work_break_taking_cached_date = date;
				}
				work_break_taking_t = 0;
			} else if (micro_pause_t > 0) {
			// oke, leaway is over, increase micro_pause_taking_t unless micro_pause is already over
				//micro_pause_t stays put
				work_break_t += tick_time;
				micro_pause_taking_t += tick_time;
				work_break_taking_t = 0;
			}
			
			// if micro_pause_taking_t is above micro_pause_duration, then micro pause is over, 
			// if still idleing workbreak_taking_t kicks in unless it is already over
			if (micro_pause_taking_t >= micro_pause_duration && work_break_t > 0) {
				work_break_taking_t += tick_time;
				micro_pause_t = 0;
			}
			
			// if work_break_taking_t is above work_break_duration, then work break is over
			if (work_break_taking_t >= work_break_duration) {
				micro_pause_t = 0;
				work_break_t = 0;
				// micro_pause_taking_t stays put
				// work_break_taking_t stays put
			}
		
			// if user needs to take a micro pause
			if (micro_pause_t >= micro_pause_period) {
				// anticipate next workbreak by not issuing this micro_pause ...
				if (work_break_t > work_break_period - (micro_pause_period / 2)) {
					work_break_t = work_break_period;
					[self doWorkBreak];
				} else {
					[self doMicroPause];
				}
			}
			
			// if user needs to take a work break
			if (work_break_t >= work_break_period) {
				// stop micro_pause stuff
				micro_pause_t = 0;
				micro_pause_taking_t = micro_pause_duration;
				// and display window
				[self doWorkBreak];
			}
		break;

		// taking a micro pause with window
		case s_taking_micro_pause:
			// continue updating timers
			micro_pause_taking_t += tick_time;
			work_break_t += tick_time;
			
			// if we don't break, or interrupt the break, reset it
			if (idle_time < 1 && !slack) {
				micro_pause_taking_t = 0;
			}
				
			// update window
			[progress setDoubleValue:micro_pause_taking_t];
			[self drawTimeLeft:micro_pause_duration - micro_pause_taking_t];
			[self drawNextBreak:work_break_period - work_break_t];

			// if user likes to be interrupted
			if (lock_focus) {
				[NSApp activateIgnoringOtherApps:YES];
				[main_window makeKeyAndOrderFront:self];
			}
			
			// check if we done enough
			if (micro_pause_taking_t > micro_pause_duration) {
				micro_pause_t = 0;
				[self endBreak];
			}
		
			// if workbreak must be run ...
			if (work_break_t >= work_break_period) {
				// stop micro_pause stuff
				micro_pause_t = 0;
				micro_pause_taking_t = micro_pause_duration;
				// and display window
				[self doWorkBreak];
			}
			break;
		
		// taking a work break with window
		case s_taking_work_break:
			// increase work_break_taking_t
			if (idle_time >= 4) {
				work_break_taking_t += tick_time;
			}
			
			// draw window
			[progress setDoubleValue:work_break_taking_t];
			[self drawTimeLeft:work_break_duration - work_break_taking_t];
			[self drawNextBreak:work_break_period + work_break_duration - work_break_taking_t];
			
			// if user likes to be interrupted
			if (lock_focus) {
				[NSApp activateIgnoringOtherApps:YES];
				[main_window makeKeyAndOrderFront:self];
			}

			// and check if we done enough
			if (work_break_taking_t > work_break_duration) {
				micro_pause_t = 0;
				micro_pause_taking_t = micro_pause_duration;
				work_break_t = 0;
				work_break_taking_t = work_break_duration;
				[self endBreak];
			}
			break;
	}
	
	// draw dock image
	if (draw_dock_image) [self drawDockImage];
}

// draw the dock icon
- (void)drawDockImage
{
	[dock_image lockFocus];
	
	// clear all
	[[NSColor clearColor] set];  
	NSRectFill(NSMakeRect(0,0,127,127));
	
	NSBezierPath* p;
	float end;
	
	//draw background circle
	[darkbackground set];
	p =[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(6,6,115,115)];
	[p setLineWidth:4];
	[p stroke];
	
	//fill
	[background set];
	[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(8,8,111,111)] fill];
	
	//put dot in middle
	[darkbackground set];
	[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(59,59,9,9)] fill];

	// reuse this one
	p = [NSBezierPath bezierPath];

	// draw work_break
	[elapsed set];
	end = 360 - (360.0 / work_break_period * work_break_t - 90);
	if (end <= 90) end=90.1;
	[p appendBezierPathWithArcWithCenter:NSMakePoint(63.5, 63.5) radius:40 startAngle:90 endAngle:end clockwise:YES];
	[p setLineWidth:22];
	[p stroke];
	
	// draw work break taking
	[taking set];
	[p removeAllPoints];
	end = 360 - (360.0 / work_break_duration * work_break_taking_t - 90);
	if (end <= 90) end=90.1;
	[p appendBezierPathWithArcWithCenter:NSMakePoint(63.5, 63.5) radius:40 startAngle:90 endAngle:end clockwise:YES];
	[p setLineWidth:18];
	[p stroke];
	
	// draw micro pause
	[elapsed set];
	[p removeAllPoints];
	end = 360 - (360.0 / micro_pause_period * micro_pause_t - 90);
	if (end <= 90) end = 90.1;
	[p appendBezierPathWithArcWithCenter:NSMakePoint(63.5, 63.5) radius:17 startAngle:90 endAngle:end clockwise:YES];
	[p setLineWidth:22];
	[p stroke];
	
	// draw micro pause taking
	[taking set];
	[p removeAllPoints];
	end = 360 - (360.0 / micro_pause_duration * micro_pause_taking_t - 90);
	if (end <= 90) end = 90.1;
	[p appendBezierPathWithArcWithCenter:NSMakePoint(63.5, 63.5) radius:17 startAngle:90 endAngle:end clockwise:YES];
	[p setLineWidth:18];
	[p stroke];
	
	[dock_image unlockFocus];

	// and set it in the dock check draw_dock_image one last time ...
	if (draw_dock_image_q) [NSApp setApplicationIconImage:dock_image];
}

// done with micro pause or work break
- (void)endBreak
{
	[main_window orderOut:NULL];
	state = s_normal;
	// reset time interval to user's choice
	[self installTimer:sample_interval];
}

// display micro_pause window with appropriate widgets and progress bar
- (void)doMicroPause
{
	micro_pause_taking_t = 0;
	[view setImage:micro_pause_image];
	[progress setMaxValue:micro_pause_duration];
	[progress setDoubleValue:micro_pause_taking_t];
	[postpone setHidden:YES];
	[self drawTimeLeft:micro_pause_duration];
	[self drawNextBreak:work_break_period - work_break_t];
	[main_window center];
	[main_window orderFrontRegardless];
	state = s_taking_micro_pause;
	// temporarily set time interval for smooth updating during the pause
	[self installTimer:0.1];
}

// display work_break window with appropriate widgets and progress bar
- (void)doWorkBreak
{
	work_break_taking_t = 0;
	// incase you were already having an implicit work break and clicked the take work break now button
	// not more then 20 seconds ago we took a natural break longer then 0.2 * normal work break duration 
	if (date - work_break_taking_cached_date < 20 && work_break_taking_cached_t > work_break_duration * 0.2) {
		work_break_taking_t = work_break_taking_cached_t;
	} 
	[view setImage:work_break_image];
	[progress setMaxValue:work_break_duration];
	[progress setDoubleValue:work_break_taking_t];
	[postpone setHidden:NO];
	[self drawTimeLeft:work_break_duration];
	[self drawNextBreak:work_break_period + work_break_duration];
	[main_window center];
	[main_window orderFrontRegardless];
	state = s_taking_work_break;
	// temporarily set time interval for smooth updating during the pause
	[self installTimer:0.1];
}

// diplays time left
- (void)drawTimeLeft:(int)seconds
{
	[time setStringValue:[NSString stringWithFormat:@"%d:%02d", seconds / 60, seconds % 60]];
}

// displays next break
- (void)drawNextBreak:(int)seconds
{
	int minutes = round(seconds / 60.0) ;
	
	// nice hours, minutes ... 
	if (minutes > 60) {
		[next_break setStringValue:[NSString stringWithFormat:@"next break in %d:%02d hours", 
			minutes / 60, minutes % 60]];
	} else {
		[next_break setStringValue:[NSString stringWithFormat:@"next break in %d minutes", minutes]];
	}
}

// goto website
- (IBAction)gotoWebsite:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:sURL]];
}

// check for update
- (IBAction)checkForUpdate:(id)sender
{
	NSString *latest_version =
	[NSString stringWithContentsOfURL: [NSURL URLWithString:sLatestVersionURL]];
	
	if (latest_version == Nil) latest_version = @"";
	latest_version = [latest_version stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	
	if ([latest_version length] == 0) {
		NSRunInformationalAlertPanel(
			@"Unable to Determine",
			@"Unable to determine the latest AntiRSI version number.",
			@"Ok", nil, nil);
	} else if ([latest_version compare:sVersion] == NSOrderedDescending) {
		int r = NSRunInformationalAlertPanel(
			@"New Version",
			[NSString stringWithFormat:@"A new version (%@) of AntiRSI is available; would you like to go to the website now?", latest_version],
			@"Goto Website", @"Cancel", nil);
		if (r == NSOKButton) {
			[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:sURL]];
		}
    } else {
    	NSRunInformationalAlertPanel(
			@"No Update Available", 
			@"This is the latest version of AntiRSI.", 
			@"OK", nil, nil);
    }
}

// stop work break and postpone by 10 minutes
- (IBAction)postpone:(id)sender
{
	if (s_taking_work_break == state) {
		micro_pause_t = 0;
		micro_pause_taking_t = 0;
		work_break_taking_t = 0;
		work_break_taking_cached_t = 0;
		work_break_t -= 10*60; // decrease with 10 minutes
		if (work_break_t < 0) work_break_t = 0;
		[self endBreak];
	}
}

- (IBAction)breakNow:(id)sender
{
	[self doWorkBreak];
}

// validate menu items
- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
	if ([[anItem title] isEqualToString:@"Take Break Now"] && state == s_normal) {
		return YES;
	}
	
	if ([[anItem title] isEqualToString:@"Postpone Break"] && state == s_taking_work_break) {
		return YES;
	}
	
	if ([[anItem title] isEqualToString:@"AntiRSI Help"]) {
		return YES;
	}
	
	return NO;
}

// we are delegate of NSApplication, so we can restore the icon on quit.
- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	// make sure timer doesn't tick once more ...
	draw_dock_image_q = NO;
	[mtimer invalidate];
	[mtimer autorelease];
	mtimer = nil;
	[dock_image release];
	// stupid fix for icon beeing restored ... it is not my fault,
	// the dock or NSImage or setApplicationIconImage seem to be caching or taking
	// snapshot or something ... !
	[NSApp setApplicationIconImage:original_dock_image];
	[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
	[NSApp setApplicationIconImage:original_dock_image];

}

@end

