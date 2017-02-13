FROM microsoft/aspnet
ARG source
WORKDIR /inetpub/wwwroot
COPY ${source:-bin/Release/PublishOutput} .
