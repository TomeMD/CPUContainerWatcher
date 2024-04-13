FROM debian:bullseye-slim AS base

RUN apt-get update && apt-get install -y sudo libcap2-bin libcurl3-gnutls

FROM base AS builder

# Set environment variables
ENV PAPI_VERSION=7.0.0
ENV RAPL_HOME=/var/lib/rapl
ENV PAPI_HOME=${RAPL_HOME}/papi-${PAPI_VERSION}
ENV RAPL_SRC=/var/lib/rapl/rapl_plot

# Install basic packages
RUN apt-get install -y build-essential gcc git

# Copy PAPI source code
RUN mkdir -p ${RAPL_HOME}
COPY --chown=0 ./src/papi-${PAPI_VERSION} ${PAPI_HOME}

# Compile PAPI
RUN cd ${PAPI_HOME}/src && \
  chmod +x configure && \
  ./configure --with-components="rapl" && \
  make

# Compile RAPL tool
COPY --chown=0 ./src/rapl_plot ${RAPL_SRC}
RUN cd ${RAPL_SRC} && \
  make && \
  setcap cap_sys_rawio=ep ${RAPL_SRC}/rapl_plot && \
  chmod +x ${RAPL_SRC}/rapl_plot

FROM base

WORKDIR /usr/local/bin
COPY --from=builder /var/lib/rapl/rapl_plot/rapl_plot ./
# Execute rapl_plot
ENTRYPOINT ["rapl_plot"]
