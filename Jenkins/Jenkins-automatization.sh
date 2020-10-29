#!/bin/bash
#==============================================START ENKINS CREATE NEW USER=======================================================
#The USER_PASS  needs to export before running.


cd ~
wget http://localhost:8080/jnlpJars/jenkins-cli.jar

export ADMIN_PASS=`cat /var/jenkins_home/secrets/initialAdminPassword`

cat <<'EOF' >test.sh
#!/bin/sh
echo 'jenkins.model.Jenkins.instance.securityRealm.createAccount("doman", "$USER_PASS")' | java -jar ./jenkins-cli.jar -s "http://localhost:8080/" -auth admin:$ADMIN_PASS groovy = –
EOF

touch test1.sh
sed 's/$USER_PASS/'"$USER_PASS"'/' test.sh > test1.sh | chmod +x test1.sh

sh test1.sh

rm -fr test1.sh test.sh


#==============================================FINISH JENKINS CREATE NEW USER=======================================================
#==============================================START INSTALL NEEDED PLUGINS=======================================================

cat <<'EOF' >plugins.txt
ant
bouncycastle-api
build-timeout
command-launcher
email-ext
github-branch-source
gradle
ldap
matrix-auth
jdk-tool
antisamy-markup-formatter
pam-auth
workflow-aggregator
pipeline-github-lib
ssh-slaves
timestamper
ws-cleanup
azure-keyvault
docker-workflow
EOF


for i in `cat plugins.txt`; do java -jar jenkins-cli.jar -s http://$HOST_IP:8081/ -auth admin:$ADMIN_PASS install-plugin $i ;done

java -jar jenkins-cli.jar -auth admin:$ADMIN_PASS -s http://$HOST_IP:8081/ restart

#==============================================FINISH INSTALL NEEDED PLUGINS=======================================================
#==============================================START CREATE JENKINS NODE=======================================================
java -jar jenkins-cli.jar -s http://$HOST_IP:8081/  -auth admin:$ADMIN_PASS -webSocket get-credentials-as-xml system::system::jenkins "(global)" VMmanual
java -jar jenkins-cli.jar -s http://$HOST_IP:8081/  -auth admin:$ADMIN_PASS -webSocket get-credentials-as-xml system::system::jenkins "(global)" dockercreds

# java -jar jenkins-cli.jar -s http://$HOST_IP:8081/  -auth admin:$ADMIN_PASS -webSocket list-credentials-as-xml system::system::jenkins

cat <<EOF >credentials.xml
<list>
  <com.cloudbees.plugins.credentials.domains.DomainCredentials plugin="credentials@2.3.13">
    <domain>
      <specifications/>
    </domain>
    <credentials>
      <com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
        <scope>GLOBAL</scope>
        <id>VMmanual</id>
        <description></description>
        <username>root</username>
        <password>$VM_PASS</password>
      </com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
    </credentials>
  </com.cloudbees.plugins.credentials.domains.DomainCredentials>
</list>
EOF

cat <<EOF >password.xml
<com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl plugin="credentials@2.3.13">
  <scope>GLOBAL</scope>
  <id>dockercreds</id>
  <description></description>
  <username>bogdanskiy</username>
  <password>
    <secret-redacted/>
  </password>
</com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl>
EOF

#The SECREDID and other AzureCredentials needs to export before running.
#AZURE SECRET CAN'T BE USED AS NODE PASSWORD.
# cat <<EOF >credentials.xml
# <list>
#   <com.cloudbees.plugins.credentials.domains.DomainCredentials plugin="credentials@2.3.13">
#     <domain>
#       <specifications/>
#     </domain>
#     <credentials>
#       <com.microsoft.azure.util.AzureCredentials plugin="azure-credentials@4.0.2">
#         <scope>GLOBAL</scope>
#         <id>AzureKeyVault</id>
#         <description></description>
#         <data>
#           <subscriptionId>$SUBSCRIPTION_ID</subscriptionId>
#           <clientId>$CLIENT_ID</clientId>
#           <clientSecret>$CLIENT_SECRET</clientSecret>
#           <certificateId></certificateId>
#           <tenant>$TENNANT_ID</tenant>
#           <azureEnvironmentName>Azure</azureEnvironmentName>
#         </data>
#       </com.microsoft.azure.util.AzureCredentials>
#       <com.microsoft.jenkins.keyvault.SecretStringCredentials plugin="azure-credentials@4.0.2">
#         <scope>GLOBAL</scope>
#         <id>VMpass</id>
#         <description></description>
#         <credentialId>AzureKeyVault</credentialId>
#           <secretIdentifier>https://doman-kv.vault.azure.net/secrets/Doman-secret/$SECRED_ID</secretIdentifier>
#       </com.microsoft.jenkins.keyvault.SecretStringCredentials>
#     </credentials>
#   </com.cloudbees.plugins.credentials.domains.DomainCredentials>
# </list>
# EOF


java -jar jenkins-cli.jar -s http://$HOST_IP:8081/ -auth doman:$USER_PASS -webSocket import-credentials-as-xml system::system::jenkins < credentials.xml
java -jar jenkins-cli.jar -s http://$HOST_IP:8081/ -auth doman:$USER_PASS -webSocket import-credentials-as-xml system::system::jenkins < password.xml



#java -jar jenkins-cli.jar -s http://$HOST_IP:8081/ -auth admin:$ADMIN_PASS get-node Node1


cat <<EOF >node.xml
<?xml version="1.1" encoding="UTF-8"?>
<slave>
  <name>Node1</name>
  <description>Digital ocean</description>
  <remoteFS>/home</remoteFS>
  <numExecutors>1</numExecutors>
  <mode>EXCLUSIVE</mode>
  <retentionStrategy class="hudson.slaves.RetentionStrategy$Always"/>
  <launcher class="hudson.plugins.sshslaves.SSHLauncher" plugin="ssh-slaves@1.31.2">
    <host>$HOST_IP</host>
    <port>22</port>
    <credentialsId>VMmanual</credentialsId>
    <launchTimeoutSeconds>60</launchTimeoutSeconds>
    <maxNumRetries>10</maxNumRetries>
    <retryWaitTime>15</retryWaitTime>
    <sshHostKeyVerificationStrategy class="hudson.plugins.sshslaves.verifiers.NonVerifyingKeyVerificationStrategy"/>
    <tcpNoDelay>true</tcpNoDelay>
  </launcher>
  <label></label>
  <nodeProperties/>
</slave>
EOF

java -jar jenkins-cli.jar -s http://$HOST_IP:8081/ -auth admin:$ADMIN_PASS create-node Node1 < node.xml



=================================================START JENKINS CREATE JOB=========================================================
#The job got using next command.
# java -jar jenkins-cli.jar -s http://$HOST_IP:8081/ -auth admin:$ADMIN_PASS -webSocket get-job DockerPush
# java -jar jenkins-cli.jar -s http://127.0.0.1:8080/ -auth doman:$USER_PASS -webSocket get-job DockerPush

cat <<EOF >job.xml
<flow-definition plugin="workflow-job@2.40">
  <actions>
    <org.jenkinsci.plugins.pipeline.modeldefinition.actions.DeclarativeJobAction plugin="pipeline-model-definition@1.7.2"/>
    <org.jenkinsci.plugins.pipeline.modeldefinition.actions.DeclarativeJobPropertyTrackerAction plugin="pipeline-model-definition@1.7.2">
      <jobProperties/>
      <triggers/>
      <parameters/>
      <options/>
    </org.jenkinsci.plugins.pipeline.modeldefinition.actions.DeclarativeJobPropertyTrackerAction>
  </actions>
  <description></description>
  <keepDependencies>false</keepDependencies>
  <properties>
    <com.dabsquared.gitlabjenkins.connection.GitLabConnectionProperty plugin="gitlab-plugin@1.5.13">
      <gitLabConnection></gitLabConnection>
    </com.dabsquared.gitlabjenkins.connection.GitLabConnectionProperty>
  </properties>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsScmFlowDefinition" plugin="workflow-cps@2.83">
    <scm class="hudson.plugins.git.GitSCM" plugin="git@4.4.4">
      <configVersion>2</configVersion>
      <userRemoteConfigs>
        <hudson.plugins.git.UserRemoteConfig>
          <url>https://github.com/bogdan-domanskiy/Kubernetes.git</url>
        </hudson.plugins.git.UserRemoteConfig>
      </userRemoteConfigs>
      <branches>
        <hudson.plugins.git.BranchSpec>
          <name>*/master</name>
        </hudson.plugins.git.BranchSpec>
      </branches>
      <doGenerateSubmoduleConfigurations>false</doGenerateSubmoduleConfigurations>
      <submoduleCfg class="list"/>
      <extensions/>
    </scm>
    <scriptPath>Jenkins/Jenkinsfile.yml</scriptPath>
    <lightweight>true</lightweight>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
EOF

java -jar jenkins-cli.jar -s http://$HOST_IP:8081/ -auth admin:$ADMIN_PASS -webSocket create-job DockerPush < job.xml
