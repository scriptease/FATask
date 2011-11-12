
/*
 * Copyright 2011 Florian Agsteiner
 */

#import "FATask.h"

int main(int argc, char* argv[]) {
    
    FATask* backgroundTask = [FATask startBackgroundTaskWithBlock:^id(FATask* task) {
        NSLog(@"Task1: Background return 42");
        return (id)[NSNumber numberWithInt:42];
    }];
    
    FATask* nextTask = [FABlockTask taskWithBlock:^id(FATask* task) {
        NSLog(@"Task1: Background continuation return %@ / 2",[task result]);
        id result = [NSNumber numberWithInt:[[task get] intValue]/2];        
        return result;
    }];
    
    [nextTask continueWithBlock:^(FATask *task) {
        NSLog(@"Task1: Background continuation with result %@", [task result]);
    }];
    
    [backgroundTask continueWithTask:nextTask];
    
    NSLog(@"Task1: Block and wait for result of task %@",[backgroundTask get]);


    
    id result = [[[FATask startBackgroundTaskWithBlock:^id(FATask* task) {
        return [NSSet setWithObjects:@"5",@"2",@"1",@"4",@"3", nil];
    }] continueWithTask:[[FABlockTask taskWithBlock:^id(FATask* task) {
        return [[task result] sortedArrayUsingComparator:^(id obj1, id obj2) {
            return (NSComparisonResult)[obj1 compare:obj2 options:NSCaseInsensitiveSearch];
        }];        
    }] continueWithBlock:^(FATask *task) {
        NSLog(@"Task2: Sorted result %@", [task result]);
    }]] get];
    
    NSLog(@"Task2: Result unsorted because continuations only propergate result 1 level %@",result);
    
    
    
    [[FATask startBackgroundTaskWithBlock:^id(FATask* task) {
        return (id)[NSNumber numberWithInt:42];
    }] continueWithMainThreadBlock:^(FATask* task) {
        NSLog(@"Task3: Mainthread response %@", [task result]);
    }];
    
    [[FATask startMainThreadTaskWithBlock:^id(FATask* task) {
        NSLog(@"Task4: main");
        return (id)[NSNumber numberWithInt:42];
    }] continueWithBackgroundTask:[[FABlockTask taskWithBlock:^id(FATask *task) {
        NSLog(@"Task4: background");
        return [NSNumber numberWithInt:[[task get] intValue]/2];        
    }] continueWithMainThreadBlock:^(FATask *task) {
        NSLog(@"Task4: main result %@", [task result]);
    }]];
    
    return 0;
}
