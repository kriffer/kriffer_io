---
title: Monitoring Java applications with JFR and Java Mission Control
date:  2020-12-30
tags: ["java", "jvm", "monitoring", "jdk"]
---

There are many cases where we try to find the answers on what is happening with our java application, why its memory keeps growing, why it suddenly becomes slower than before etc.

To answer these questions we use different diagnostic tools and approaches that may shed some light on the cause of the issues, and here we are going to take a brief look at Java Flight Recorder(JFR) and Java Mission Control tool that provides data visualization of collected JFR recordings.

There are lot of specific articles, tutorials, how-tos about JFR and JMC, but here is just a brief guideline on how to monitor a Java application and gather data to analyze.

JFR – event based tracing technology built into Java runtime with very low overhead (<1%) so it can be used in production.

It generates events that are produced by Java application and JVM, filtered, stored in memory, on disk, in thread-local buffers, and look like:

- Environment information (CPU, OS, cmd line, JDK, etc.)
- Java execution (threads, IO …)
- VM operations (class loading, GC, JIT compiler)
Sample usage to activate recording directly on JVM launch, useful for short test runs:

~~~sh
%/.java -XX:StartFlightRecording=name=myapp,filename=apprecording.jfr -jar application.jar
~~~

To start a recording later during runtime there are no options are needed on the application’s JVM side.

For controlling the data collection during the runtime we can use jcmd tool. First start the recording into the cyclic buffer, after some time dump the content of the cyclic buffer into a file and stop further recording:

~~~sh jcmd JAVAPID JFR.start
jcmd JAVAPID JFR.dump name=1 filename=/anydirectory/recording.jfr
jcmd JAVAPID JFR.stop
~~~


**JMC Usage**

There are several JMC builds that various vendors offer – just pick and use what you like.

- Adopt OpenJDK JMC https://adoptopenjdk.net/jmc.html
- Azul Zulu Mission Control https://www.azul.com/products/zulu-mission-control/
- Liberica Mission Control https://bell-sw.com/pages/lmc-7.1.1/
- Oracle JMC https://www.oracle.com/java/technologies/javase/products-jmc7-downloads.html

Actually, there is no much difference which one to use, since those all implementations are based on the same codebase and components.

The current version of JMC is 8 but it is expected JMC8 to be released at the nearest (you can take the latest snapshot builds here https://adoptopenjdk.net/jmc.html).

By default, the executable  `${JMC_HOME}/jmc ` command will use the JVM it finds in the operating systems’ current executable search path (PATH environment variable) as java command. To use a specific JVM to start JMC on Linux or MacOS use the `-vm` option and to add other JVM options use the `-vmargs` option.

Example:

~~~sh 
/opt/jmc7.0.0/jmc -vm /usr/lib/jvm/java-8/bin/javac -vmargs -Xmx8G` 
~~~

Depending on the number of recorded events in the JFR file, loading large JFR recordings can require large heapsizes on the JMC side.

**Useful features**

- Overview-Memory graph – very useful to see memory pools and areas dynamically. Just add needed metrics into the graph (most useful are Committed virtual memory, committed java heap, used heap, used non-heap)
- Memory tab with active memory pools and Heap Histogram. Refresh heap histogram panel and you will get memory delta for each class.
- Diagnostic Commands tab –  VM.native_memory  command. It allows getting Native Memory Tracking (NMT) data from JMC (should be adjusted  -`XX:NativeMemoryTracking=detail`  flag first). 

Additionally, it is useful to change boolean values for this command to get all the features of jcmd tool for NMT (baseline, detail.diff, summary etc. )