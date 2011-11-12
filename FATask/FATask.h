/*
 * Copyright 2011 Florian Agsteiner
 */

#import "FAFuture.h"
#import "FADispatch.h"

@class NSException;
@class NSMutableArray;

@class FATask;

@protocol FATask <NSObject>

@property(nonatomic, assign, readonly, getter = isFinished) BOOL finished;

@property(nonatomic, retain, readonly) NSException* error;

- (id) executeWithTask: (FATask*) previousTask;

@optional

/**
 * Wait if necessary for the computation to complete, and then retrieve its result
 */
- (id) get;

@end

@interface FATask : NSObject <FATask,FAFuture> {
@private
    /**
     * Store the result of the task when it's finished 
     */
    /*[property: {getter, setter: {private}}]*/
    id _result;
    
    /**
     * The Task if finished if the block was executed. For errors check @see error.  
     */
    /*[property: {getter, setter: {private}}]*/
    BOOL _finished;
    
    /**
     * Stores a exception of the block 
     */
    /*[property: {getter, setter: {private}}]*/
    NSException* _error;
    
    dispatch_group_t _privateGroup;
    dispatch_queue_t _privateQueue;
    
    dispatch_queue_t _queue;
    dispatch_group_t _group;
    
    NSMutableArray* _continuations;
}

- (FATask*) init;

/**
 *  Overwrite me and perform custom Tasks!!!
 */
- (id) executeWithTask: (FATask*) previousTask;

- (void) start;
- (void) startWithDispatchQueue: (dispatch_queue_t) queue;
- (void) startWithDispatchQueue: (dispatch_queue_t) queue group: (dispatch_group_t) group;

+ (FATask*) startTaskWithBlock: (id (^)(FATask* task)) block dispatchQueue: (dispatch_queue_t) queue;
+ (FATask*) startTaskWithBlock: (id (^)(FATask* task)) block dispatchQueue: (dispatch_queue_t) queue group: (dispatch_group_t) group;

+ (FATask*) startBackgroundTaskWithBlock:(id (^)(FATask* task)) block;
+ (FATask*) startMainThreadTaskWithBlock:(id (^)(FATask* task)) block;

- (FATask*) continueWithTask:(FATask*) task;
- (FATask*) continueWithTask:(FATask*) task dispatchQueue: (dispatch_queue_t) queue;
- (FATask*) continueWithTask:(FATask*) task dispatchQueue: (dispatch_queue_t) queue group: (dispatch_group_t) group;

- (FATask*) continueWithBackgroundTask:(FATask*) task;
- (FATask*) continueWithMainThreadTask:(FATask*) task;

- (FATask*) continueWithBlock: (void (^)(FATask* task)) block; 
- (FATask*) continueWithBlock: (void (^)(FATask* task)) block dispatchQueue: (dispatch_queue_t) queue; 
- (FATask*) continueWithBlock: (void (^)(FATask* task)) block dispatchQueue: (dispatch_queue_t) queue group: (dispatch_group_t) group; 

- (FATask*) continueWithBackgroundBlock:(void (^)(FATask* task)) block;
- (FATask*) continueWithMainThreadBlock:(void (^)(FATask* task)) block;

+ (void) performInBackground: (id (^)()) backgroundBlock continuation: (void (^)(id result, NSException* error)) continuation;
+ (void) performInBackground: (id (^)()) backgroundBlock continuation: (void (^)(id result, NSException* error)) continuation group: (dispatch_group_t) group;

+ (void) performInBackground: (id (^)()) backgroundBlock mainThreadContinuation: (void (^)(id result, NSException* error)) continuation;
+ (void) performInBackground: (id (^)()) backgroundBlock mainThreadContinuation: (void (^)(id result, NSException* error)) continuation group: (dispatch_group_t) group;


+ (id) task;
- (void) dealloc;
@property(nonatomic, retain, readwrite) id result;
@property(nonatomic, assign, readwrite, getter=isFinished) BOOL finished;
@property(nonatomic, retain, readwrite) NSException * error;

@end

@interface FABlockTask : FATask <FATask,FAFuture> {
@private
    /**
     * The block to be executed in the task
     */
    /*[property: {getter}]*/
    id (^_block)(FATask* task);
}

- (FATask*) initWithBlock: (id (^)(FATask* task)) block;

+ (id) taskWithBlock: (id (^)(FATask* task)) block;

@property(nonatomic, copy, readonly) id (^ block )(FATask* task);

@end
