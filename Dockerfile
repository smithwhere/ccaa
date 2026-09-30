FROM alpine:3.11.6

WORKDIR /root
RUN wget https://raw.githubusercontent.com/smithwhere/ccaa/master/docker-ccaa.sh && sh docker-ccaa.sh install
VOLUME /data/ccaaDown
EXPOSE 6080 6081 6082 6800 51413