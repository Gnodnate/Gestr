#import "GestureSetupView.h"

@implementation GestureSetupView

@synthesize setupController, detectingInput;

- (id)initWithFrame:(NSRect)frame {
	self = [super initWithFrame:frame];
    
	touchPaths = [[NSMutableDictionary alloc] init];
	gestureStrokes = [NSMutableDictionary dictionary];
	orderedStrokeIds = [NSMutableArray array];
    
	lastMultitouchRedraw = [NSDate date];
    
	return self;
}

- (void)dealWithMouseEvent:(NSEvent *)event ofType:(NSString *)mouseType {
	if (!setupController.useMultitouchTrackpad && detectingInput) {
        [setupController.drawNowText setAlphaValue:0.0];
        
        if (noInputTimer) {
			[noInputTimer invalidate];
			noInputTimer = nil;
		}
        
		if (shouldDetectTimer) {
			[shouldDetectTimer invalidate];
			shouldDetectTimer = nil;
		}
        
		NSPoint drawPoint = [self convertPoint:[event locationInWindow] fromView:nil];
        
		if ([mouseType isEqualToString:@"down"]) {
			mouseStrokeIndex++;
		}
        
		NSNumber *identity = [NSNumber numberWithInt:mouseStrokeIndex];
        
		if (![gestureStrokes objectForKey:identity]) {
			[orderedStrokeIds addObject:identity];
			[gestureStrokes setObject:[[GestureStroke alloc] init] forKey:identity];
		}
        
		GesturePoint *detectorPoint = [[GesturePoint alloc] initWithX:(drawPoint.x / self.frame.size.width) * boundingBoxSize andY:(drawPoint.y / self.frame.size.height) * boundingBoxSize andStroke:[identity intValue]];
        
		[[gestureStrokes objectForKey:identity] addPoint:detectorPoint];
        
		if ([mouseType isEqualToString:@"down"]) {
			NSBezierPath *tempPath = [NSBezierPath bezierPath];
			[tempPath setLineWidth: 7.0];
			[tempPath setLineCapStyle:NSRoundLineCapStyle];
			[tempPath setLineJoinStyle:NSRoundLineJoinStyle];
			[tempPath moveToPoint:drawPoint];
            
			[touchPaths setObject:tempPath forKey:identity];
		}
		else if ([mouseType isEqualToString:@"drag"]) {
			NSBezierPath *tempPath = [touchPaths objectForKey:identity];
			[tempPath lineToPoint:drawPoint];
		}
		else if ([mouseType isEqualToString:@"up"]) {
			if (!shouldDetectTimer) {
				shouldDetectTimer = [NSTimer scheduledTimerWithTimeInterval:((float)setupController.readingDelayNumber) / 1000.0 target:self selector:@selector(finishDetectingGesture) userInfo:nil repeats:NO];
			}
            
			NSBezierPath *tempPath = [touchPaths objectForKey:identity];
			[tempPath lineToPoint:drawPoint];
		}
        
		[self setNeedsDisplay:YES];
	}
}

- (void)mouseDown:(NSEvent *)theEvent {
	[self dealWithMouseEvent:theEvent ofType:@"down"];
}

- (void)mouseDragged:(NSEvent *)theEvent {
	[self dealWithMouseEvent:theEvent ofType:@"drag"];
}

- (void)mouseUp:(NSEvent *)theEvent {
	[self dealWithMouseEvent:theEvent ofType:@"up"];
}

- (void)dealWithMultitouchEvent:(MultitouchEvent *)event {
	if (setupController.useMultitouchTrackpad && detectingInput) {
        [setupController.drawNowText setAlphaValue:0.0];
        
		if (!initialMultitouchDeviceId) {
			initialMultitouchDeviceId = event.deviceIdentifier;
		}
        
		if ([event.deviceIdentifier isEqualToNumber:initialMultitouchDeviceId]) {
			if (noInputTimer) {
				[noInputTimer invalidate];
				noInputTimer = nil;
			}
            
			if (shouldDetectTimer) {
				[shouldDetectTimer invalidate];
				shouldDetectTimer = nil;
			}
            
			if (!shouldDetectTimer && event.touches.count == 0) {
				shouldDetectTimer = [NSTimer scheduledTimerWithTimeInterval:((float)setupController.readingDelayNumber) / 1000.0 target:self selector:@selector(finishDetectingGesture) userInfo:nil repeats:NO];
			}
			else {
				if ([lastMultitouchRedraw timeIntervalSinceNow] * -1000.0 > 18) {
					for (MultitouchTouch *touch in event.touches) {
                        float combinedTouchVelocity = fabs(touch.velX) + fabs(touch.velY);
                        if (touch.state == 4 && combinedTouchVelocity > 0.06) {
                            NSPoint drawPoint = NSMakePoint(touch.x, touch.y);
                            
                            NSNumber *identity = touch.identifier;
                            
                            if (![gestureStrokes objectForKey:identity]) {
                                [orderedStrokeIds addObject:identity];
                                [gestureStrokes setObject:[[GestureStroke alloc] init] forKey:identity];
                            }
                            
                            GesturePoint *detectorPoint = [[GesturePoint alloc] initWithX:drawPoint.x * boundingBoxSize andY:drawPoint.y * boundingBoxSize andStroke:[identity intValue]];
                            
                            [[gestureStrokes objectForKey:identity] addPoint:detectorPoint];
                            
                            drawPoint.x *= self.frame.size.width;
                            drawPoint.y *= self.frame.size.height;
                            
                            NSBezierPath *tempPath;
                            if ((tempPath = [touchPaths objectForKey:identity])) {
                                [tempPath lineToPoint:drawPoint];
                            }
                            else {
                                tempPath = [NSBezierPath bezierPath];
                                [tempPath setLineWidth: 7.0];
                                [tempPath setLineCapStyle:NSRoundLineCapStyle];
                                [tempPath setLineJoinStyle:NSRoundLineJoinStyle];
                                [tempPath moveToPoint:drawPoint];
                                
                                [touchPaths setObject:tempPath forKey:identity];
                            }
                        }
					}
                    
					[self setNeedsDisplay:YES];
					lastMultitouchRedraw = [NSDate date];
				}
			}
		}
	}
}

- (void)startDealingWithMultitouchEvents {
	[[MultitouchManager sharedMultitouchManager] addMultitouchListenerWithTarget:self callback:@selector(dealWithMultitouchEvent:) andThread:nil];
}

- (void)showGesture:(Gesture *)gesture {
	showingStoredGesture = YES;
    
	[self resetAll];
	if (gesture) {
		int pointIndex = 0;
		while (true) {
			if ([[NSThread currentThread] isCancelled] || detectingInput) {
				[NSThread exit];
			}
            
			if (pointIndex % 2 == 0) {
				[self setNeedsDisplay:YES];
			}
            
			pointIndex++;
            
			BOOL contin;
			for (GestureStroke *stroke in gesture.strokes) {
				if (pointIndex < stroke.pointCount) {
					contin = true;
					break;
				}
			}
            
			if (!contin) {
				break;
			}
            
			for (int strokeIndex = 0; strokeIndex < gesture.strokes.count; strokeIndex++) {
				GestureStroke *cStroke = [gesture.strokes objectAtIndex:strokeIndex];
				if (pointIndex < cStroke.pointCount) {
					GesturePoint *cPoint = [cStroke.points objectAtIndex:pointIndex];
                    
					NSPoint drawPoint = NSMakePoint([cPoint getX] / boundingBoxSize * self.frame.size.width, [cPoint getY] / boundingBoxSize * self.frame.size.height);
                    
					NSString *ident = [NSString stringWithFormat:@"%i", strokeIndex];
                    
					if (pointIndex == 1) {
						NSBezierPath *tempPath = [NSBezierPath bezierPath];
						[tempPath setLineWidth:7.0];
						[tempPath setLineCapStyle:NSRoundLineCapStyle];
						[tempPath setLineJoinStyle:NSRoundLineJoinStyle];
						[tempPath moveToPoint:drawPoint];
						[touchPaths setObject:tempPath forKey:ident];
					}
					else if (pointIndex > 1 && pointIndex < [cStroke pointCount]) {
						NSBezierPath *tempPath = [touchPaths objectForKey:ident];
						[tempPath lineToPoint:drawPoint];
					}
					else if (pointIndex == [cStroke pointCount]) {
						NSBezierPath *tempPath = [touchPaths objectForKey:ident];
						[tempPath lineToPoint:drawPoint];
						[touchPaths removeObjectForKey:ident];
					}
				}
			}
            
			[NSThread sleepForTimeInterval:0.007];
		}
	}
    
	showingStoredGesture = NO;
}

- (void)startDetectingGesture {
	[self resetAll];
    
    mouseStrokeIndex = 0;
    
	initialMultitouchDeviceId = nil;
    
	[setupController.drawNowText setAlphaValue:1.0];
    
	noInputTimer = [NSTimer scheduledTimerWithTimeInterval:5.0 target:self selector:@selector(checkNoInput) userInfo:nil repeats:NO];
    
	if (setupController.useMultitouchTrackpad) {
		[self performSelector:@selector(startDealingWithMultitouchEvents) withObject:nil afterDelay:0.2];
		CGAssociateMouseAndMouseCursorPosition(NO);
	}
    
	[self becomeFirstResponder];
    
    detectingInput = YES;
}

- (void)checkNoInput {
	if (!gestureStrokes || gestureStrokes.count == 0) {
		[self finishDetectingGesture:YES];
	}
}

- (void)finishDetectingGesture {
	[self finishDetectingGesture:NO];
}

- (void)finishDetectingGesture:(BOOL)ignore {
    [[MultitouchManager sharedMultitouchManager] removeMultitouchListersWithTarget:self andCallback:@selector(dealWithMultitouchEvent:)];
	CGAssociateMouseAndMouseCursorPosition(YES);
    
	detectingInput = NO;
    
	[setupController.drawNowText setAlphaValue:0.0];
    
	if (!ignore) {
		NSMutableArray *orderedStrokes = [NSMutableArray array];
		for (int i = 0; i < [orderedStrokeIds count]; i++) {
			[orderedStrokes addObject:[gestureStrokes objectForKey:[orderedStrokeIds objectAtIndex:i]]];
		}
        
		[setupController saveGestureWithStrokes:orderedStrokes];
	}
    
	[setupController updateSetupControls];
    
	[self resetAll];
}

- (void)resetAll {
	if (shouldDetectTimer) {
		[shouldDetectTimer invalidate];
		shouldDetectTimer = nil;
	}
    
	if (noInputTimer) {
		[noInputTimer invalidate];
		noInputTimer = nil;
	}
    
	gestureStrokes = [NSMutableDictionary dictionary];
	orderedStrokeIds = [NSMutableArray array];
	[touchPaths removeAllObjects];
    
	[self setNeedsDisplay:YES];
}

- (BOOL)acceptsFirstResponder {
	return YES;
}

- (BOOL)canBecomeKeyView {
	return YES;
}

- (void)drawRect:(NSRect)dirtyRect {
	if (detectingInput || showingStoredGesture) {
		[[NSColor colorWithCalibratedRed:0 green:0 blue:0 alpha:0.35] setStroke];
		for (NSBezierPath *path in[touchPaths allValues]) {
			NSBezierPath *whitePath = [path copy];
			[whitePath setLineWidth:[path lineWidth] * 1.4];
			[whitePath stroke];
		}
        
		[myGreenColor setStroke];
		for (NSBezierPath *path in[touchPaths allValues]) {
			[path stroke];
		}
	}
}

@end
