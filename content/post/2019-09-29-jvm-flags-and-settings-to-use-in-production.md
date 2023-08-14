---
title: JVM flags and settings to use in production
date:  2019-09-29
tags: ["java", "jvm", "monitoring", "jdk"]
---

There are cases when we face issues coming from production instances and that needs to be investigated and solved as soon as possible. In most cases we are trying to make postmortem analysis that makes a root cause identifying a quite challenging. Here there are some setting are supposed be used to obtain initial information about any sorts of applications issues like crashes, performance degradations, memory leaks and resource consumption.

Defining heap size explicitly:

`-Xmx<SIZE>` – heap size for the java instance. (Example: -Xmx20g or -Xmx1024m)

GC logging:

`-Xloggc:$(date -u +%Y-%b-%d-%H-%M).gc.log`

`-XX:+PrintGCDetails`

Keeping GC logging enabled helps to identify varios range of problems with memory leaks, pauses and allows to make a fine tuning of GC for concrete instance. For the instances that care about latency it is recommended to have compilation logging that can help to figure out the compiling behavior and possible delays that are related to deoptimizations.

Compilation logging:

`-XX:+PrintCompilation `

`-XX:+PrintCompileDateStamps`  

`-XX:+LogVMOutput`  

`-XX:LogFile=/any/directory/compilation.log`

Additionally for deoptimizations and inlining events logging:

`-XX:+TraceDeoptimization` 

`-XX:+PrintInlining`

The compilation logging can help to identify whether the particular method was the cause of the delays that are related to deoptimisations, which tier (e g Int, C1, C2) and allows to define further actions to resolve the issue – to review the method code, to exclude this method from compilation etc.

**Crash information**

We know that the java instance leaves the hs_err file (default location – process directory) when gets crashed. This file contains a lot of valuable information about signals that led to crash, memory dump, environment, stack traces, memory mapping, dynamic libraries etc etc. There are many reasons what crash can happen, but in most cases, it is segmentation faults that are caused by the application code, libraries the process uses, or even by VM internals. In some cases having just hs_err file is not enough to obtain a full picture of an issue and what can be the cause. Here the core dumping can help for analysis of the crash nature. The core dumps can be used for debugging and getting backtraces that can help to identify what exact code caused the wrong memory access (e. g in the case of SIGSEGV).

In Linux environment in it recommended to enable core dumping by using Linux command (with root privileges):

`ulimit -c unlimited`

If there is enough space for dumping a crashed process the core file will be created (the size will be pretty same as the java instance size). By default, the core file is written to the location defined in `/proc/sys/kernel/core_pattern`

For Windows environment to enable core dumping it is suggested to add this flag:

`-XX:+CreateMinidumpOnCrash`

or enable mini cores on the system level as described here: https://docs.microsoft.com/en-us/windows/win32/wer/collecting-user-mode-dumps

To get the list and default values of the JVM flags:

`$ java -XX:+PringFlagsFinal -version`

In addition, a very useful resource to obtain the information of the flags for different JVM implementations and versions:

https://chriswhocodes.com/hotspot_options_jdk11.html