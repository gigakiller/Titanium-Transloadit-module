/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2012 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiTransloaditClientProxy.h"
#import "TiApp.h"
#import "TiBase.h"
#import "TiHost.h"
#import "TiUtils.h"
#import "TiBlob.h"
#import "TiFilesystemFileProxy.h"

@implementation TiTransloaditClientProxy

#pragma mark Initialization and Deinitialization

-(id)init
{
    if ((self = [super init]))
    {
    }
    return self;
}

-(void)dealloc
{
	RELEASE_TO_NIL(successCallback);
    RELEASE_TO_NIL(errorCallback);
    RELEASE_TO_NIL(cancelCallback);
    RELEASE_TO_NIL(progressCallback);
    RELEASE_TO_NIL(templateId);
    RELEASE_TO_NIL(authSecret);
    [super dealloc];
}

#pragma Helper Methods

-(void)sendSuccessEvent:(id)response withStatus:(NSString*)status
{
	if (successCallback != nil){
		NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
			status,@"status",
			response,@"response",
			nil
		];
		
		// Fire an event directly to the specified listener (callback)
		[self _fireEventToListener:@"onload" withObject:event listener:successCallback thisObject:nil];
	}
}

-(void)sendErrorEvent:(id)message withTitle:(NSString*)title
{
	if (errorCallback != nil){
		NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
			message,@"message",
			title,@"title",
			nil
		];
		
		// Fire an event directly to the specified listener (callback)
		[self _fireEventToListener:@"onerror" withObject:event listener:errorCallback thisObject:nil];
	}
}

-(void)sendCancelEvent:(id)message withTitle:(NSString*)title
{
	if (cancelCallback != nil){
		// Fire an event directly to the specified listener (callback)
		[self _fireEventToListener:@"oncancel" withObject:nil listener:cancelCallback thisObject:nil];
	}
}

-(void)sendProgressEvent:(id)arg withProgress:(float)progress
{
	if (progressCallback != nil){
		NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithFloat:progress],@"progress",
			nil
		];
		
		// Fire an event directly to the specified listener (callback)
		[self _fireEventToListener:@"onerror" withObject:event listener:progressCallback thisObject:nil];
	}
}

- (void)startUploadFromPicker:(NSDictionary *)info
{
	// this will get released in the Transloadit SDK
	NSString *tempSecret = authSecret;
	
	transload = [[TransloaditRequest alloc] initWithCredentials:[self valueForUndefinedKey:@"authkey"] secret:tempSecret];
	[transload setTemplateId:[self valueForUndefinedKey:@"templateId"]];
	[transload addPickedFile:info];
	[transload setNumberOfTimesToRetryOnTimeout:5];
	[transload setDelegate:self];
	[transload setUploadProgressDelegate:self];
	[transload startAsynchronous];
}

-(void)setAuthsecret:(id)value
{
	// this is called automatically when we run transloadit.createClient() from javascript
	// we need to retain authsecret because the Transloadit module releases it without taking ownership in it's dealloc method
	authSecret = [[TiUtils stringValue:value] retain];
	[self replaceValue:value forKey:@"authsecret" notification:NO];
}

-(void)setTemplateId:(id)value
{
	templateId = [TiUtils stringValue:value];
	[self replaceValue:templateId forKey:@"templateId" notification:NO];
}

#pragma Public APIs

/**
 * Uploads a file (from local path) to transloadit.
 *
 * @param  id		 		file (either String, TiBlob, or TiFilesystemFile)
 * @param  NSString  		filename (eg: @"myFile.wav")
 * @param  NSString  		type (eg: @"audio/wav")
 * @param  NSString  		templateId (eg: @"abcdef12345")
 * @param  KrollCallback  	onload (called when request is complete)
 * @param  KrollCallback  	onerror (called if error occurs)
 * @param  KrollCallback  	onsendstream (called while data is being sent)
 *
 * @returns  void
 */

-(void)uploadFile:(id)args
{
	ENSURE_SINGLE_ARG_OR_NIL(args,NSDictionary);

	NSMutableDictionary *errMsg = [[NSMutableDictionary alloc] init];

	TiBlob *blob = nil;
	NSString *path = nil;

	// callbacks
	RELEASE_TO_NIL(successCallback);
	RELEASE_TO_NIL(errorCallback);
	RELEASE_TO_NIL(progressCallback);
	successCallback = [[args valueForKey:@"onload"] retain];
	errorCallback = [[args valueForKey:@"onerror"] retain];
	progressCallback = [[args valueForKey:@"onsendstream"] retain];
	
	// quit if file was not provided
	if([args valueForKey:@"file"] == nil)
	{
		NSLog(@"No file provided");
		if (errorCallback!=nil)
		{
			[errMsg setObject:@"No file provided" forKey:@"error"];
			[self _fireEventToListener:@"onerror" withObject:errMsg listener:errorCallback thisObject:nil];
		}
		RELEASE_TO_NIL(errMsg);
		return;
	}
	
	NSString *filename = [TiUtils stringValue:[args valueForKey:@"filename"]];
	NSString *type = [TiUtils stringValue:[args valueForKey:@"type"]];
	NSString *tempId = [TiUtils stringValue:[args valueForKey:@"templateId"]];
	
	NSString *tempSecret = authSecret;
	
	transload = [[TransloaditRequest alloc] initWithCredentials:[self valueForUndefinedKey:@"authkey"] secret:tempSecret];
	[transload setTemplateId:tempId];
	
	// determine what was passed as "file"
	if ([[args valueForKey:@"file"] isKindOfClass:[TiFilesystemFileProxy class]])
	{
		// NSLog(@"*** FILE IS CLASS TiFilesystemFileProxy");
		path = [[args valueForKey:@"file"] description];
	}
	else if ([[args valueForKey:@"file"] isKindOfClass:[TiBlob class]])
	{
		// NSLog(@"*** FILE IS CLASS TiBlob");
		blob = [args valueForKey:@"file"];
	}
	else if ([[args valueForKey:@"file"] isKindOfClass:[NSString class]])
	{
		// NSLog(@"*** FILE IS CLASS NSString");
		path = [args valueForKey:@"file"];
	}
	else
	{
		NSLog(@"File must be of type String, TiBlob, or Ti.Filesystem.File");
		if (errorCallback!=nil)
		{
			[errMsg setObject:@"File must be of type String, TiBlob, or Ti.Filesystem.File" forKey:@"error"];
			[self _fireEventToListener:@"onerror" withObject:errMsg listener:errorCallback thisObject:nil];
		}
		RELEASE_TO_NIL(errMsg);
		return;
	}
	
	// check for a blob or path to use for the upload
	if(blob != nil)
	{
		[transload addRawData:[blob data] withFileName:filename addContentType:type];
	}
	else if(path != nil)
	{
		[transload addRawFile:path withFileName:filename addContentType:type];
	}
	else
	{
		NSLog(@"Could not find a file to upload");
		if (errorCallback!=nil)
		{
			[errMsg setObject:@"Could not find a file to upload" forKey:@"error"];
			[self _fireEventToListener:@"onerror" withObject:errMsg listener:errorCallback thisObject:nil];
		}
		RELEASE_TO_NIL(errMsg);
		return;
	}
	
	[transload setNumberOfTimesToRetryOnTimeout:5];
	[transload setDelegate:self];
	[transload setUploadProgressDelegate:self];
	[transload startAsynchronous];
	
	[errMsg release];
}

/**
 * Uploads a file from a generic gallery to transloadit.
 *
 * @param  NSString  		templateId (eg: @"abcdef12345")
 * @param  KrollCallback  	onload (called when request is complete)
 * @param  KrollCallback  	onerror (called if error occurs)
 * @param  KrollCallback  	onsendstream (called while data is being sent)
 *
 * @returns  void
 */
- (void)uploadFromGallery:()args
{
	ENSURE_SINGLE_ARG_OR_NIL(args,NSDictionary);
	ENSURE_UI_THREAD(uploadFromGallery,args);
	
	// added this to fix zombie crash
	NSDictionary *_args = [args retain];
	
	[self setTemplateId:[TiUtils stringValue:[args valueForKey:@"templateId"]]];
	
	// callbacks
	RELEASE_TO_NIL(successCallback);
	RELEASE_TO_NIL(errorCallback);
	RELEASE_TO_NIL(cancelCallback);
	RELEASE_TO_NIL(progressCallback);
	successCallback = [[args valueForKey:@"onload"] retain];
	errorCallback = [[args valueForKey:@"onerror"] retain];
	cancelCallback = [[args valueForKey:@"oncancel"] retain];
	progressCallback = [[args valueForKey:@"onsendstream"] retain];
	
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.mediaTypes = [UIImagePickerController availableMediaTypesForSourceType:UIImagePickerControllerSourceTypePhotoLibrary];
	picker.delegate = self;
	[[[TiApp app] controller] presentModalViewController:picker animated:YES];
}

#pragma mark Delegates

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
	[self startUploadFromPicker:info];
	
	[picker dismissModalViewControllerAnimated:YES];
	RELEASE_TO_NIL(picker);
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
	[[TiApp app] hideModalController:picker animated:YES];
	RELEASE_TO_NIL(picker);
	
	[self sendCancelEvent:@"" withTitle:@""];
}

- (void)requestFinished:(TransloaditRequest *)transloadRequest
{
	NSString *responseStatus = [[NSString alloc] initWithString:@""];
	NSString *response = [[NSString alloc] initWithString:@""];
	if([transloadRequest response] != nil)
	{
		response = [transloadRequest response];
	}
	if ([transloadRequest hadError]) 
    {
		responseStatus = [response objectForKey:@"error"];
	} 
    else 
    {
		responseStatus = [response objectForKey:@"ok"];
	}
	
    [self sendSuccessEvent:response withStatus:responseStatus];
    RELEASE_TO_NIL(transload);
}

- (void)setProgress:(float)currentProgress
{
	[self sendProgressEvent:@"" withProgress:currentProgress];
}

@end