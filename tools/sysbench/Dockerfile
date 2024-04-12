FROM debian:bullseye-slim

COPY run-sysbench.sh /usr/local/bin/sysbench/

RUN apt-get update && apt-get install -y sudo curl && \
    curl -s https://packagecloud.io/install/repositories/akopytov/sysbench/script.deb.sh | sudo bash && \
    sudo apt -y install sysbench && \
    chmod +x /usr/local/bin/sysbench/run-sysbench.sh

ENTRYPOINT ["/usr/local/bin/sysbench/run-sysbench.sh"]