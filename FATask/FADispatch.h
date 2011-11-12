/*
 * Copyright 2011 Florian Agsteiner
 */

#import <Foundation/NSObject.h>

#import <dispatch/dispatch.h>
#import <CoreFoundation/CFDate.h>

/**
 * Dispatch synchronously without deadlocking.
 */
static inline void dispatch_safe_sync(dispatch_queue_t queue, void (^block)(void)) {
    if(queue == dispatch_get_current_queue()) {
        block();
    }
    else {
        dispatch_sync(queue, block);
    }
}

/**
 * Dispatch asyncronously without deadlocking.
 */
static inline void dispatch_safe_async(dispatch_queue_t queue, void (^block)(void)) {
    if(queue == dispatch_get_current_queue()) {
        block();
    }
    else {
        dispatch_async(queue, block);
    }
}

/**
 * Dispatch asyncronously into a group without deadlocking.
 */
static inline void dispatch_safe_group(dispatch_group_t group, dispatch_queue_t queue, void (^block)(void)) {
    if(queue == dispatch_get_current_queue()) {
        block();
    }
    else {
        dispatch_group_async(group, queue, block);
    }
}
