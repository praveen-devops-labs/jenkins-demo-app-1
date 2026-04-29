FROM tomcat:9-jdk17

COPY target/app1.war /usr/local/tomcat/webapps/ROOT.war
