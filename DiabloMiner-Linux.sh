#!/bin/sh
export GPU_USE_SYNC_OBJECTS=1
export DISPLAY=`echo $DISPLAY | sed 's/\.[0-9]//'`
export COMPUTE=$DISPLAY
cd $(dirname ${0})
exec java -Xmx32m -cp target/libs/*:target/DiabloMiner.jar -Djava.library.path=target/libs/natives com.diablominer.DiabloMiner.DiabloMiner $@
