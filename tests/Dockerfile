FROM alpine
MAINTAINER ahpnils <nils.github@anotherhomepage.org>

RUN apk update
RUN apk add bind

EXPOSE 53
CMD ["/usr/sbin/named", "-v"]
