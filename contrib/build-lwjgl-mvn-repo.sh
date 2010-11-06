#!/bin/sh

if test -z "$1"; then
  echo "No version number provided"
  exit
fi

sed -e "s/VERSION/$1/g" lwjgl.pom > lwjgl-$1.pom

mvn deploy:deploy-file -DartifactId=lwjgl -Dfile=lwjgl-docs-$1.zip -Dclassifier=javadoc -Dpackaging=jar -DgroupId=org.lwjgl -Dversion=$1 -DrepositoryID=lwjgl -Durl=file:./lwjgl

mvn deploy:deploy-file -DartifactId=lwjgl -Dfile=lwjgl-source-$1.zip -Dclassifier=source -Dpackaging=jar -DgroupId=org.lwjgl -Dversion=$1 -DrepositoryID=lwjgl -Durl=file:./lwjgl

unzip lwjgl-$1.zip

mvn deploy:deploy-file -DartifactId=lwjgl -Dfile=lwjgl-$1/jar/lwjgl_test.jar -Dpackaging=test-jar -DgroupId=org.lwjgl -Dversion=$1 -DrepositoryID=lwjgl -Durl=file:./lwjgl

mvn deploy:deploy-file -DartifactId=lwjgl -Dfile=lwjgl-$1/jar/lwjgl.jar -Dpackaging=jar -DgroupId=org.lwjgl -Dversion=$1 -DrepositoryID=lwjgl -Durl=file:./lwjgl -DgeneratePom=false -DpomFile=lwjgl-$1.pom

mvn deploy:deploy-file -DartifactId=lwjgl-debug -Dfile=lwjgl-$1/jar/lwjgl-debug.jar -Dpackaging=jar -DgroupId=org.lwjgl -Dversion=$1 -DrepositoryID=lwjgl -Durl=file:./lwjgl

mvn deploy:deploy-file -DartifactId=lwjgl-jinput -Dfile=lwjgl-$1/jar/jinput.jar -Dpackaging=jar -DgroupId=org.lwjgl -Dversion=$1 -DrepositoryID=lwjgl -Durl=file:./lwjgl

mvn deploy:deploy-file -DartifactId=lwjgl-util -Dfile=lwjgl-$1/jar/lwjgl_util.jar -Dpackaging=jar -DgroupId=org.lwjgl -Dversion=$1 -DrepositoryID=lwjgl -Durl=file:./lwjgl

cd ./lwjgl-$1/native
zip -r -9  ../native.zip ./
cd ../..

mvn deploy:deploy-file -DartifactId=lwjgl-native -Dfile=lwjgl-$1/native.zip -Dpackaging=jar -DgroupId=org.lwjgl -Dversion=$1 -DrepositoryID=lwjgl -Durl=file:./lwjgl

rm -rf lwjgl-$1/

