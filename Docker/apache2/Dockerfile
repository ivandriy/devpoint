###########################################
# Dockerfile to build an apache2 image
###########################################
# Base image is Ubuntu
FROM ubuntu:14.04
MAINTAINER Andrii Ivanskiy andrii@ivanskiy.com
# Install apache2 package
RUN apt-get update && \
     apt-get install -y apache2 && \
     apt-get clean
# Set the log directory PATH
ENV APACHE_LOG_DIR /var/log/apache2
# Expose port 80
EXPOSE 80
# Launch apache2 server in the foreground
ENTRYPOINT ["/usr/sbin/apache2ctl", "-D", "FOREGROUND"]