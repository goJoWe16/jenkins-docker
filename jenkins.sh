#! /bin/bash

# lets define some env vars for easier kubernetes integration
export KUBERNETES_MASTER=https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}
export KUBERNETES_TRUST_CERT=true
export SKIP_TLS_VERIFY=true
export KUBERNETES_NAMESPACE=default
export BUILD_NAMESPACE=default

# lets startup socat so we can access the docker socket over http from Java code
socat tcp-listen:2375,fork unix:/var/run/docker.sock &

# Copy files from /usr/share/jenkins/ref into /var/jenkins_home
# So the initial JENKINS-HOME is set with expected content. 
# Don't override, as this is just a reference setup, and use from UI 
# can then change this, upgrade plugins, etc.
copy_reference_file() {
  f=${1%/}
  echo "$f" >> $COPY_REFERENCE_FILE_LOG
  rel=${f:23}
  dir=$(dirname ${f})
  echo " $f -> $rel" >> $COPY_REFERENCE_FILE_LOG
  if [[ ! -e /var/jenkins_home/${rel} ]]; then
    echo "copy $rel to JENKINS_HOME" >> $COPY_REFERENCE_FILE_LOG
    mkdir -p /var/jenkins_home/${dir:23}
    cp -r /usr/share/jenkins/ref/${rel} /var/jenkins_home/${rel};
    # pin plugins on initial copy
    [[ ${rel} == plugins/*.jpi ]] && touch /var/jenkins_home/${rel}.pinned
  fi;
}

export -f copy_reference_file
echo "--- Copying files at $(date)" >> $COPY_REFERENCE_FILE_LOG
find /usr/share/jenkins/ref/ -type f -exec bash -c 'copy_reference_file {}' \;

#Set the serverUrl for the docker-plugins
#sed -ie 's/docker.url/'"${HOSTNAME}"'/g' /var/jenkins_home/config.xml
DOCKER_HOST=`get-host-ip.sh`
sed -ie 's/docker.url/'"$DOCKER_HOST"'/g' /var/jenkins_home/config.xml

# Generate ssh key
ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa
mkdir -p /home/jenkins/ssh-keys/
cp ~/.ssh/id_rsa.pub /home/jenkins/ssh-keys/authorized_keys
chmod -R 775 /home/jenkins/ssh-keys/authorized_keys

# if `docker run` first argument start with `--` the user is passing jenkins launcher arguments
if [[ $# -lt 1 ]] || [[ "$1" == "--"* ]]; then
   exec java $JAVA_OPTS -jar /usr/share/jenkins/jenkins.war $JENKINS_OPTS "$@"
fi

# As argument is not jenkins, assume user want to run his own process, for sample a `bash` shell to explore this image
exec "$@"
