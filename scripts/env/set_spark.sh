#!/bin/bash
set -x

QEMU_SET() {
	echo "export HDFS_NAMENODE_USER="skannan"" &>> ~/.bashrc
	echo "export HDFS_DATANODE_USER="skannan"" &>> ~/.bashrc
	echo "export HDFS_SECONDARYNAMENODE_USER="skannan"" &>> ~/.bashrc
	echo "export YARN_RESOURCEMANAGER_USER="skannan"" &>> ~/.bashrc
	echo "export YARN_NODEMANAGER_USER="skannan"" &>> ~/.bashrc
}

ADD_SPARK_TO_BASHRC() {
	SPARK_HOME=$APPBENCH/apps/spark
	HADOOP_HOME=$SPARK_HOME/hadoop-3.2.1
	echo "export SPARK_HOME=/users/skannan/ssd/NVM/appbench/apps/spark" &>> ~/.bashrc
	echo "export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin" &>> ~/.bashrc
	echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64/jre" &>> ~/.bashrc
	echo "export HADOOP_HOME=$SPARK_HOME/hadoop-3.2.1" &>> ~/.bashrc
	echo "export HADOOP_INSTALL=$HADOOP_HOME" &>> ~/.bashrc
	echo "export HADOOP_MAPRED_HOME=$HADOOP_HOME" &>> ~/.bashrc
	echo "export HADOOP_COMMON_HOME=$HADOOP_HOME" &>> ~/.bashrc
	echo "export HADOOP_HDFS_HOME=$HADOOP_HOME" &>> ~/.bashrc
	echo "export YARN_HOME=$HADOOP_HOME" &>> ~/.bashrc
	echo "export HADOOP_COMMON_LIB_NATIVE_DIR=$HADOOP_HOME/lib/native" &>> ~/.bashrc
	echo "export PATH=$PATH:$HADOOP_HOME/sbin:$HADOOP_HOME/bin" &>> ~/.bashrc
	echo "export HADOOP_OPTS="-Djava.library.path=$HADOOP_HOME/lib/native"" &>> ~/.bashrc
	ssh-keygen
	cat ~/.ssh/id_rsa.pub &>> ~/.ssh/authorized_keys
}

INSTALL_SPARK_HIBENCH(){
	cd $APPBENCH/apps
	SPARKFILE=spark-2.4.4-bin-hadoop2.7.tgz
	SPARKDIR=$APPBENCH/apps/spark
	HIBENCHDIR=$SPARKDIR/HiBench
	SPARKBENCH=$SPARKDIR/spark-bench
        SPARKFILES=$APPBENCH/apps/spark_files
	HADOOP="hadoop-3.2.1"
	HADOOP_DIR=$SPARKDIR/$HADOOP


	# Check if Spark file exists?
	if [ -f $SPARKFILE ]; then
	  	  echo "$SPARKFILE exist"
	else 
		wget https://www.apache.org/dist/spark/spark-2.4.4/$SPARKFILE
		tar -xvzf $SPARKFILE
	fi

	if [ -d $SPARKDIR ]; then
		echo "$SPARKDIR exist"
	else
		mv spark-2.4.4-bin-hadoop2.7 $SPARKDIR
	fi
	cd $SPARKDIR

	if [ -f $HADOOP".tar.gz" ]; then
  	  echo "$HADOOP".tar.gz" exist"
	else 
	    wget http://apache.mirrors.pair.com/hadoop/common/$HADOOP/$HADOOP".tar.gz"
	    tar -xvzf $HADOOP".tar.gz"
	fi
	cd $SPARKDIR/$HADOOP
	cp -r $SPARKFILES/$HADOOP/etc/hadoop/* $SPARKDIR/$HADOOP/etc/hadoop/
	cp -r $SPARKFILES/$HADOOP/bin/* $SPARKDIR/$HADOOP/bin/
	cp -r $SPARKFILES/$HADOOP/sbin/* $SPARKDIR/$HADOOP/sbin/
	cp $SPARKFILES/conf/spark-defaults.conf $SPARKDIR/conf/
	cp $SPARKFILES/bin/* $SPARKDIR/bin/*

        #git clone https://github.com/Intel-bigdata/HiBench
        #cd $HIBENCHDIR
	#mvn -Dspark=2.1 -Dscala=2.11 clean package
	#cp $SPARKFILES/$HADOOP/etc/* $HADOOP_DIR/etc/
        #cp $SPARKFILES/HiBench/conf/* $HIBENCHDIR/conf/ 
	
	cd $SPARKDIR
	git clone https://github.com/CODAIT/spark-bench -b legacy
	cd $SPARKBENCH
	git clone https://github.com/synhershko/wikixmlj.git
	cd wikixmlj
	mvn package install
	cd $SPARKBENCH
	bin/build-all.sh
	cp -r $SPARKFILES/spark-bench/conf .
        cp -r $SPARKFILES/spark-bench/bin .
	
}
source scripts/setvars.sh
#INSTALL_SPARK_HIBENCH
ADD_SPARK_TO_BASHRC
QEMU_SET
