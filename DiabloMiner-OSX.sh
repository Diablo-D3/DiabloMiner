#!/bin/sh
export GPU_USE_SYNC_OBJECTS=1
cd $(dirname ${0})
java -Xmx32m -cp target/libs/*:target/DiabloMiner.jar -Djava.awt.headless=true -Djava.library.path=target/libs/natives/macosx com.diablominer.DiabloMiner.DiabloMiner $@
