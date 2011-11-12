/*
 * Copyright 2011 Florian Agsteiner
 */

#import <Foundation/NSObject.h>

/**
 * A result of an asynchronous computation
 *
 * @see http://java.sun.com/javase/6/docs/api/java/util/concurrent/Future.html
 */
@protocol FAFuture <NSObject>

/**
 * Wait if necessary for the computation to complete, and then retrieve its result
 */
- (id) get;

/**
 * Wait if necessary for the computation to complete, and then retrieve its result into buffer @a buf
 */
- (void) get: (void*) buf;

@end
