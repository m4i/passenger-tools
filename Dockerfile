FROM debian:jessie

# install passenger
RUN apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7 \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends apt-transport-https ca-certificates \
	&& echo deb https://oss-binaries.phusionpassenger.com/apt/passenger jessie main > /etc/apt/sources.list.d/passenger.list \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends passenger \
	&& rm -r /var/lib/apt/lists/*

WORKDIR /app

# install ruby
RUN apt-get update \
	&& apt-get install -y --no-install-recommends ruby \
	&& rm -r /var/lib/apt/lists/*

EXPOSE 3000
CMD ["passenger-start", "--delay-on-graceful-stop", "5s", "--memory-limit", "500", "--max-requests", "1000", "--timestamp"]

COPY test /app
COPY passenger-start passenger-monitor /usr/local/bin/
