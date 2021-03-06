#!/bin/bash

if [[ -z $1 ]];
then
  echo "Usage: $0 <class_version> [force|skip-images]"
  exit 1;
fi

SKIP_IMAGES=
FORCE=
REBUILD=
if [[ $2 == "force" ]]; then
  FORCE=true
  echo -e "NOTE: Rebuilding classroom environment, removing any local changes..."
elif [[ $2 == "skip-images" ]]; then
  SKIP_IMAGES=true
  echo -e "NOTE: Skipping Docker image file updates..."
fi

#The repos need updating on the Ubuntu VM
sed '$d' /etc/apt/sources.list.d/hdp.list
echo "http://public-repo-1.hortonworks.com/HDP/ubuntu12/2.1.3.0" >> /etc/apt/sources.list.d/hdp.list

export REPO_DIR=$1
#Determine the course directory, which is the first part of the REPO_DIR up until the underscore character
COURSE_DIR=${REPO_DIR%%_*}
export COURSE_DIR=`echo $COURSE_DIR | tr '[:upper:]' '[:lower:]'`
mkdir -p /root/$COURSE_DIR
echo -e "Course files being copied to /root/$COURSE_DIR"

cd /root/$REPO_DIR
if [[ ! -z $FORCE ]];
then
  git reset HEAD --hard
fi
git pull

cd /root/dockerfiles
if [[ ! -z $FORCE ]];
then
  git reset HEAD --hard
fi
git pull

if [[ (-z $SKIP_IMAGES) && (! -z $FORCE) ]];
then

# Build the Docker images

# Build hwxu/hdp_node_base first
cd /root/dockerfiles/hdp_node_base
x=$(docker images | grep -c  hwxu/hdp_node_base)
if [ $x == 0 ]; then
        echo -e "\n*** Building hwxu/hdp_node_base image... ***\n"
        docker build -t hwxu/hdp_node_base .
        echo -e "Build of hwxu/hdp_node_base complete!"
        # Build hwxu/hdp_node
		echo -e "\n*** Building hwxu/hdp_node ***\n"
		cd /root/dockerfiles/hdp_node
		docker build -t hwxu/hdp_node .
		echo -e "\n*** Build of hwxu/hdp_node complete! ***\n"

		#If this script is execute multiple times, untagged images get left behind
		#This command removes any untagged Docker images
		docker rmi -f $(docker images | grep '^<none>' | awk '{print $3}')

else
        echo -e "\n*** hwxu/hdp_node_base image already built ***\n"
fi

# Build hwxu/hdp_node
echo -e "\n*** Building hwxu/hdp_node ***\n"
cd /root/dockerfiles/hdp_node
docker build -t hwxu/hdp_node .
echo -e "\n*** Build of hwxu/hdp_node complete! ***\n"

#If this script is execute multiple times, untagged images get left behind
#This command removes any untagged Docker images
docker rmi -f $(docker images | grep '^<none>' | awk '{print $3}')

fi


# Copy utility scripts into /root/scripts, which is already in the PATH
echo "Copying utility scripts..."
cp /root/dockerfiles/start_scripts/* /root/scripts/
cp /root/$REPO_DIR/scripts/* /root/scripts/

#echo "Copying config files..."
#cp /root/dockerfiles/hdp_node/configuration_files/core_hadoop/* /etc/hadoop/conf/
#cp /root/dockerfiles/hdp_node/configuration_files/tez/* /etc/tez/conf/
#cp /root/dockerfiles/hdp_node/configuration_files/hive/* /etc/hive/conf/
#cp /root/dockerfiles/hdp_node/configuration_files/pig/* /etc/pig/conf/

#Copy lab files
echo "Copying lab files..."
mkdir -p /root/$COURSE_DIR/labs
cp -r /root/$REPO_DIR/labs/*  /root/$COURSE_DIR/labs/

#Remove any known hosts (to avoid ssh issues)
rm -rf /root/.ssh/known_hosts

echo -e "\n*** Parent build.sh successfully built ***\n"
