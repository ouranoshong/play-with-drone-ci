FROM alpine:latest

ENV WorkDir=/home/api

LABEL matainer="value"

RUN mkdir -p ${WorkDir}}

WORKDIR ${WorkDir}

COPY app ${WorkDir}/

RUN chmod +x ${WorkDir}/app
        
EXPOSE 80

CMD ["./app"]