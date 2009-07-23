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

#import "AntiRSIView.h"

@implementation AntiRSIView

- (id)initWithFrame:(NSRect)frameRect
{
	if ((self = [super initWithFrame:frameRect]) != nil) {
		// Add initialization code here
	}
	return self;
}

- (void)drawRect:(NSRect)rect
{
	[[NSColor clearColor] set];
    NSRectFill([self frame]);
	[_image compositeToPoint:NSZeroPoint operation:NSCompositeSourceOver];
	
}

- (void)setImage:(NSImage *)image;
{
	_image = image;
	[self setNeedsDisplay:YES];
}
@end