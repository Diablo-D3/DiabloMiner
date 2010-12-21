#!/bin/sh
export GPU_USE_SYNC_OBJECTS=1
java -cp target/libs/*:target/DiabloMiner-0.0.1-SNAPSHOT.jar -Djava.library.path=target/libs/natives/solaris com.diablominer.DiabloMiner.DiabloMiner $@
