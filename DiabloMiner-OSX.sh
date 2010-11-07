#!/bin/sh
java -cp target/libs/*:target/DiabloMiner-0.0.1-SNAPSHOT.jar -Djava.library.path=target/libs/natives/macosx com.diablominer.DiabloMiner.DiabloMiner $@
