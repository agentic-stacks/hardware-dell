ARG ROCKY_VERSION="9"
FROM rockylinux:${ROCKY_VERSION}

LABEL maintainer="agentic-stacks"
LABEL description="Dell PowerEdge hardware management toolkit — iDRAC, BIOS, RAID, firmware"

# renovate: datasource=pypi depName=ansible
ARG ANSIBLE_VERSION="10.6.0"

# renovate: datasource=galaxy-collection depName=dellemc.openmanage
ARG GALAXY_DELLOM_VERSION="9.9.0"

# Dell download URLs — full URLs as args so operators can swap versions without editing the Dockerfile
# Dell's dl.dell.com blocks non-browser User-Agents, so we set a browser-like UA for all downloads
ARG IDRAC_TOOLS_URL="https://dl.dell.com/FOLDER09667202M/1/Dell-iDRACTools-Web-LX-11.1.0.0-5294_A00.tar.gz"
ARG PERCCLI_URL="https://dl.dell.com/FOLDER09074160M/1/PERCCLI_7.211.0_Linux.tar.gz"
ARG MVCLI_URL="https://dl.dell.com/FOLDER06354567M/1/mvcli_5.0.13.1109_A00.zip"

ENV DELL_UA="User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/131.0.0.0"

# Core system packages
RUN \
  dnf update -y && \
  dnf install -y \
    bash \
    dmidecode \
    git \
    ipmitool \
    kmod \
    lldpd \
    lshw \
    net-tools \
    OpenIPMI \
    pciutils \
    python3-pip \
    wget \
    usbutils \
    util-linux \
    unzip && \
  dnf clean all && \
  rm -rf /var/cache/yum

# Ansible + Dell OpenManage collection
RUN \
  pip install --no-cache-dir ansible==${ANSIBLE_VERSION} && \
  ansible-galaxy collection install dellemc.openmanage:==${GALAXY_DELLOM_VERSION} && \
  pip install --no-cache-dir -r ~/.ansible/collections/ansible_collections/dellemc/openmanage/requirements.txt

# Dell iDRAC racadm tools
RUN \
  wget --header="$DELL_UA" ${IDRAC_TOOLS_URL} -O /tmp/idrac-tools.tar.gz && \
  cd /tmp && \
  tar -xvf idrac-tools.tar.gz && \
  rpm -ivhf --nodeps iDRACTools/racadm/SLES15/x86_64/* && \
  rm -rf /tmp/idrac-tools.tar.gz /tmp/iDRACTools

# Marvell RAID CLI (mvcli) for Marvell-based RAID controllers (S140/S150)
RUN \
  wget --header="$DELL_UA" ${MVCLI_URL} -O /tmp/mvcli.zip && \
  cd /tmp && \
  unzip mvcli.zip -d mvcli && \
  cp mvcli/x64/cli/mvcli /usr/local/bin/ && \
  chmod +x /usr/local/bin/mvcli && \
  mv mvcli/x64/cli/libmvraid.so /usr/lib && \
  rm -rf /tmp/mvcli /tmp/mvcli.zip

# Dell PERC CLI for PERC RAID controllers
RUN \
  wget --header="$DELL_UA" ${PERCCLI_URL} -O /tmp/perccli.tar.gz && \
  cd /tmp && \
  tar zxvf perccli.tar.gz && \
  rpm -ivh perccli-*.noarch.rpm && \
  cp /opt/MegaRAID/perccli/perccli64 /usr/local/bin/ && \
  rpm -e perccli && \
  rm -rf /tmp/perccli.tar.gz /tmp/perccli-*

# Working directory for operator configs
WORKDIR /workspace

# Entrypoint: start the iDRAC service driver, then run the user's command
# The instsvcdrv-helper is required for racadm local commands to communicate
# with the iDRAC hardware. Without it, local racadm operations will fail.
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
