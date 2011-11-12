FATask: Mix aus Future und Continuations
========================================

Future:
-------

* Asynchroner Task der ein Ergebnis liefert das erst noch berechnet werden muss.
* Ausführbarer Thread kann Task asynchron starten, wenn er das Ergebnis braucht, kann eine Methode get aufrufen die solange blockiert bis der Task fertig ist.
* Exceptions beim asynchronen Task werden aufgehoben und an den Aufrufenden geworfen.  
	
Continuation:
-------------

* Angabe eines Block oder Tasks, der das Ergebnis eines vorhergehenden Tasks auswerten kann
* Die Continuation wird ausgeführt wenn der vorhergehende Tasks fertig ist und das Ergebnis feststeht.
*Exceptions des vorhergehenden Tasks werden weitergegeben.
	
Task:
-----

* Wrapper um eine einzige synchrone Methode die ein Ergebnis zurückgibt oder eine Exception wirft;
* BlockTask: Implementation eines Tasks mit einem Block der selben Signatur
	
* Ein Task kann die Ergebnisse des Vorgängers über [previousTask result] und [previousTask error] benutzen.
	
Synchrone Ausführung
--------------------

Diese Methode führt den Task aus, sie sollte auch überschrieben werden bei eigenen Subklassen,
wahlweise kann man auch die FABlockTask Implementierung hernehmen ohne eigene Klasse. 

```
- (id) executeWithTask: (FATask*) previousTask;
```

Asynchrone Ausführung
---------------------

Beim asynchronen Aufruf kann eine dispatch group oder queue mit gegeben werden die den Ort der Ausführung spezifiziert.
Das Ganze funktioniert Deadlock frei egal wie die Tasks aufeinander folgen

```
	- (void) start;
	- (void) startWithDispatchQueue: (dispatch_queue_t) queue;
	- (void) startWithDispatchQueue: (dispatch_queue_t) queue group: (dispatch_group_t) group;

	+ (FATask*) startTaskWithBlock: (id (^)(FATask* task)) block dispatchQueue: (dispatch_queue_t) queue;
	+ (FATask*) startTaskWithBlock: (id (^)(FATask* task)) block dispatchQueue: (dispatch_queue_t) queue group: (dispatch_group_t) group;

	+ (FATask*) startBackgroundTaskWithBlock:(id (^)(FATask* task)) block;
	+ (FATask*) startMainThreadTaskWithBlock:(id (^)(FATask* task)) block;
```
	
Continuations
-------------

Solange ein Taskobjekt existiert können beliebig viele Continuations registriert werden:
* Die Registrierung soll nicht blockieren
* Wenn ein Task noch nicht fertig ist wird auf seine Fertigstellung gewartet
* Wenn ein Task fertig war wird die Continuation ausgeführt.

```
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
```

Häufig gebrauchte Tasks
-----------------------

```
	+ (void) performInBackground: (id (^)()) backgroundBlock continuation: (void (^)(id result, NSException* error)) continuation;
	+ (void) performInBackground: (id (^)()) backgroundBlock continuation: (void (^)(id result, NSException* error)) continuation group: (dispatch_group_t) group;

	+ (void) performInBackground: (id (^)()) backgroundBlock mainThreadContinuation: (void (^)(id result, NSException* error)) continuation;
	+ (void) performInBackground: (id (^)()) backgroundBlock mainThreadContinuation: (void (^)(id result, NSException* error)) continuation group: (dispatch_group_t) group;
```

Beispiele:
==========


Verkettung von 3 Tasks:
-----------------------

```
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
```

Generierung und Sortierung einer Liste anschließend Ausgabe
-----------------------------------------------------------

```
	FATask* task = [[FATask startBackgroundTaskWithBlock:^id(FATask* task) {
	
		// Erster Task: Generierung einer Liste
        return [NSSet setWithObjects:@"5",@"2",@"1",@"4",@"3", nil];

    }] continueWithTask:[[FABlockTask taskWithBlock:^id(FATask* task) {

		// Zweiter Task: Sortierung der Liste
        return [[task result] sortedArrayUsingComparator:^(id obj1, id obj2) {
            return (NSComparisonResult)[obj1 compare:obj2 options:NSCaseInsensitiveSearch];
        }];        

    }] continueWithBlock:^(FATask *task) {

		// Dritter Task: Ergebnis ausgeben
        NSLog(@"Task2: Sorted result %@", [task result]);
    }]];
    
	// Benutzen des Ergebnisses des Tasks 1
	id result = [task  get];
    NSLog(@"Task2: Result unsorted because continuations only propergate result 1 level %@",result);
```

Vereinfachte Weitergabe an den Mainthread
-----------------------------------------

```
[[FATask startBackgroundTaskWithBlock:^id(FATask* task) {

    return (id)[NSNumber numberWithInt:42];

}] continueWithMainThreadBlock:^(FATask* task) {

    NSLog(@"Task3: Mainthread response %@", [task result]);

}];
```

Vereinfachte Weitergabe an den Mainthread (ohne Deadlocks)
----------------------------------------------------------

```
[[FATask startMainThreadTaskWithBlock:^id(FATask* task) {

    NSLog(@"Task4: main");
    return (id)[NSNumber numberWithInt:42];

}] continueWithBackgroundTask:[[FABlockTask taskWithBlock:^id(FATask *task) {

    NSLog(@"Task4: background");
    return [NSNumber numberWithInt:[[task get] intValue]/2];        

}] continueWithMainThreadBlock:^(FATask *task) {

    NSLog(@"Task4: main result %@", [task result]);

}]];
```