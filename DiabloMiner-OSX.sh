#!/bin/sh
export GPU_USE_SYNC_OBJECTS=1
cd $(dirname ${0})
exec java -Xmx32m -cp target/libs/*:target/DiabloMiner.jar -Djava.awt.headless=true -Djava.library.path=target/libs/natives com.diablominer.DiabloMiner.DiabloMiner $@
