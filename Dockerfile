ARG BASE_CONTAINER=jupyter/base-notebook@sha256:9ef1b336d2adefd5e27b2bdb98c08efa7358d3fe8090014e9515833acdda4537

FROM $BASE_CONTAINER
# https://hub.docker.com/layers/jupyter/base-notebook/lab-2.2.9/images/sha256-9ef1b336d2adefd5e27b2bdb98c08efa7358d3fe8090014e9515833acdda4537?context=explore
# https://hub.docker.com/layers/jupyter/base-notebook/lab-2.0.1/images/sha256-caf663fd9344275af065c740cfc4fe686119b7640313251c7777dae53c104031?context=explore
# https://hub.docker.com/r/jupyter/base-notebook/tags

#LABEL maintainer="James Brock <jamesbrock@gmail.com>"

# Extra arguments to `stack build`. Used to build --fast, see Makefile.
ARG STACK_ARGS=

USER root

# The global snapshot package database will be here in the STACK_ROOT.
ENV STACK_ROOT=/opt/stack
RUN mkdir -p $STACK_ROOT
RUN fix-permissions $STACK_ROOT

# Install Haskell Stack and its dependencies , texlive-fonts-recommended
RUN apt-get update && apt-get install -yq --no-install-recommends make \
        python3-pip \
        git \
	wget \
	texlive-xetex texlive-generic-recommended pandoc cm-super \
        libtinfo-dev \
        libzmq3-dev \
        libcairo2-dev \
        libpango1.0-dev \
        libmagic-dev \
        libblas-dev \
        liblapack-dev \
        libffi-dev \
        libgmp-dev \
        gnupg \
        netbase \
# for ihaskell-graphviz
        graphviz \
# for Stack download
        curl \
# Stack Debian/Ubuntu manual install dependencies
# https://docs.haskellstack.org/en/stable/install_and_upgrade/#linux-generic
        g++ \
        gcc \
        libc6-dev \
        libffi-dev \
        libgmp-dev \
        xz-utils \
        zlib1g-dev \
        git \
        gnupg \
        netbase 
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 
# Stack Linux (generic) Manual download
# https://docs.haskellstack.org/en/stable/install_and_upgrade/#linux-generic
#
# So that we can control Stack version, we do manual install instead of
# automatic install:
#
#    curl -sSL https://get.haskellstack.org/ | sh
#
ARG STACK_VERSION="2.5.1"
ARG STACK_BINDIST="stack-${STACK_VERSION}-linux-x86_64"
RUN    cd /tmp \
    && curl -sSL --output ${STACK_BINDIST}.tar.gz https://github.com/commercialhaskell/stack/releases/download/v${STACK_VERSION}/${STACK_BINDIST}.tar.gz \
    && tar zxf ${STACK_BINDIST}.tar.gz \
    && cp ${STACK_BINDIST}/stack /usr/bin/stack \
    && rm -rf ${STACK_BINDIST}.tar.gz ${STACK_BINDIST} \
    && stack --version

# Stack global non-project-specific config stack.config.yaml
# https://docs.haskellstack.org/en/stable/yaml_configuration/#non-project-specific-config
RUN mkdir -p /etc/stack
COPY stack.config.yaml /etc/stack/config.yaml
RUN fix-permissions /etc/stack

# Stack global project stack.stack.yaml
# https://docs.haskellstack.org/en/stable/yaml_configuration/#yaml-configuration
RUN mkdir -p $STACK_ROOT/global-project
COPY stack.stack.yaml $STACK_ROOT/global-project/stack.yaml
RUN    chown --recursive $NB_UID:users $STACK_ROOT/global-project \
    && fix-permissions $STACK_ROOT/global-project 

# fix-permissions for /usr/local/share/jupyter so that we can install
# the IHaskell kernel there. Seems like the best place to install it, see
#      jupyter --paths
#      jupyter kernelspec list
RUN    mkdir -p /usr/local/share/jupyter \
    && fix-permissions /usr/local/share/jupyter \
    && mkdir -p /usr/local/share/jupyter/kernels \
    && fix-permissions /usr/local/share/jupyter/kernels

# Now make a bin directory for installing the ihaskell executable on
# the PATH. This /opt/bin is referenced by the stack non-project-specific
# config.
RUN    mkdir -p /opt/bin \
    && fix-permissions /opt/bin
ENV PATH ${PATH}:/opt/bin

# Specify a git branch for IHaskell (can be branch or tag).
# The resolver for all stack builds will be chosen from
# the IHaskell/stack.yaml in this commit.
ARG IHASKELL_COMMIT=master

# Specify a git branch for hvega
ARG HVEGA_COMMIT=master

# Change this line to invalidate the Docker cache so that the IHaskell and
# hvega repos are forced to pull and rebuild when built on DockerHub.
# This is inelegant, but is there a better way? (IHASKELL_COMMIT=hash
# doesn't work.)
RUN echo "built on 2020-05-16"

# Clone IHaskell and install ghc from the IHaskell resolver
RUN    cd /opt \
    && git clone --depth 1 --branch $IHASKELL_COMMIT https://github.com/gibiansky/IHaskell \
    && git clone --depth 1 --branch $HVEGA_COMMIT https://github.com/DougBurke/hvega.git \
# Copy the Stack global project resolver from the IHaskell resolver.
    && grep 'resolver:' /opt/IHaskell/stack.yaml >> $STACK_ROOT/global-project/stack.yaml \
    && echo "extra-deps:" >> $STACK_ROOT/global-project/stack.yaml \
    && echo "- magic-1.1" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- Chart-cairo-1.9.3" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- cairo-0.13.8.0" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- gtk2hs-buildtools-0.13.8.0" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- diagrams-cairo-1.4.1.1" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- pango-0.13.8.0" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- glib-0.13.8.0" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- plot-0.2.3.10" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- lukko-0.1.1.2" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- static-canvas-0.2.0.3" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- hackage-security-0.6.0.1" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- xformat-0.1.2.1" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- HList-0.5.0.0" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- discrimination-0.4" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- /opt/IHaskell" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- /opt/IHaskell/ipython-kernel" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- /opt/IHaskell/ghc-parser" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- /opt/IHaskell/ihaskell-display/ihaskell-aeson" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- /opt/IHaskell/ihaskell-display/ihaskell-blaze" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- /opt/IHaskell/ihaskell-display/ihaskell-charts" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- /opt/IHaskell/ihaskell-display/ihaskell-diagrams" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- /opt/IHaskell/ihaskell-display/ihaskell-gnuplot" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- /opt/IHaskell/ihaskell-display/ihaskell-graphviz" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- /opt/IHaskell/ihaskell-display/ihaskell-hatex" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- /opt/IHaskell/ihaskell-display/ihaskell-juicypixels" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- /opt/IHaskell/ihaskell-display/ihaskell-magic" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- /opt/IHaskell/ihaskell-display/ihaskell-plot" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- /opt/IHaskell/ihaskell-display/ihaskell-rlangqq" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- /opt/IHaskell/ihaskell-display/ihaskell-static-canvas" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- /opt/IHaskell/ihaskell-display/ihaskell-widgets" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "- /opt/hvega/hvega" >>  $STACK_ROOT/global-project/stack.yaml \
    && echo "allow-newer: false" >>  $STACK_ROOT/global-project/stack.yaml \
    && fix-permissions /opt/IHaskell \
    && fix-permissions $STACK_ROOT \
    && fix-permissions /opt/hvega \
    && stack setup \
    && fix-permissions $STACK_ROOT

# Build IHaskell
RUN    stack build $STACK_ARGS ihaskell \
# Note that we are NOT in the /opt/IHaskell directory here, we are
# installing ihaskell via the paths given in /opt/stack/global-project/stack.yaml
    && stack build $STACK_ARGS ghc-parser \
    && stack build $STACK_ARGS ipython-kernel \
    && fix-permissions $STACK_ROOT

# Install IHaskell.Display libraries
# https://github.com/gibiansky/IHaskell/tree/master/ihaskell-display
RUN    stack build $STACK_ARGS ihaskell-aeson \
    && stack build $STACK_ARGS ihaskell-blaze \
    && stack build $STACK_ARGS ihaskell-charts \
    && stack build $STACK_ARGS ihaskell-diagrams \
    && stack build $STACK_ARGS ihaskell-gnuplot \
    && stack build $STACK_ARGS ihaskell-graphviz \
    && stack build $STACK_ARGS ihaskell-hatex \
    && stack build $STACK_ARGS ihaskell-juicypixels \
    && stack build $STACK_ARGS ihaskell-magic \
    && stack build $STACK_ARGS ihaskell-plot \
    && stack build $STACK_ARGS ihaskell-hvega \
    && stack build $STACK_ARGS hvega \
    #&& stack build $STACK_ARGS ihaskell-rlangqq \
    && stack build $STACK_ARGS ihaskell-static-canvas \
# Skip install of ihaskell-widgets, they don't work.
# See https://github.com/gibiansky/IHaskell/issues/870
    && stack build $STACK_ARGS ihaskell-widgets \
    && fix-permissions $STACK_ROOT

# Cleanup
# Don't clean IHaskell/.stack-work, 7GB, this causes issue #5
#   && rm -rf $(find /opt/IHaskell -type d -name .stack-work) \
# Don't clean /opt/hvega
# We can't actually figure out anything to cleanup.

# Bug workaround for https://github.com/jamesdbrock/ihaskell-notebook/issues/9
RUN mkdir -p /home/jovyan/.local/share/jupyter/runtime \
    && fix-permissions /home/jovyan/.local \
    && fix-permissions /home/jovyan/.local/share \
    && fix-permissions /home/jovyan/.local/share/jupyter \
    && fix-permissions /home/jovyan/.local/share/jupyter/runtime

# Install system-level ghc using the ghc which was installed by stack
# using the IHaskell resolver.
RUN mkdir -p /opt/ghc && ln -s `stack path --compiler-bin` /opt/ghc/bin \
    && fix-permissions /opt/ghc
ENV PATH ${PATH}:/opt/ghc/bin

# Switch back to jovyan user
USER $NB_UID

RUN pip install --upgrade pip \
    && pip install -U bash_kernel matlab_kernel redis_kernel sshkernel zsh_jupyter_kernel jupyterlab_geojson cookiecutter qgrid \
    && python3 -m bash_kernel.install \
    && conda update -y -n base conda \
    && conda install -y -c r r-irkernel 

RUN \
# Install the IHaskell kernel at /usr/local/share/jupyter/kernels, which is
# in `jupyter --paths` data:
       stack exec ihaskell -- install --stack --prefix=/usr/local \
# Install the ihaskell_labextension for JupyterLab syntax highlighting
    && npm install -g typescript \
    && cd /opt/IHaskell/ihaskell_labextension \
    && npm install \
    && npm run build \
    && jupyter labextension install . \
    && jupyter labextension install jupyterlab-spreadsheet repa jupyterlab-drawio @ijmbarr/jupyterlab_spellchecker @jupyter-widgets/jupyterlab-manager qgrid2 \
# Cleanup
    && npm cache clean --force \
    && rm -rf /home/$NB_USER/.cache/yarn \
# Clean ihaskell_labextensions/node_nodemodules, 86MB
    && rm -rf /opt/IHaskell/ihaskell_labextension/node_modules

# Example IHaskell notebooks will be collected in this directory.
ARG EXAMPLES_PATH=/home/$NB_USER/ihaskell_examples

# Collect all the IHaskell example notebooks in EXAMPLES_PATH.
RUN    mkdir -p $EXAMPLES_PATH \
    && cd $EXAMPLES_PATH \
    && mkdir -p ihaskell \
    && cp --recursive /opt/IHaskell/notebooks/* ihaskell/ \
    && mkdir -p ihaskell-juicypixels \
    && cp /opt/IHaskell/ihaskell-display/ihaskell-juicypixels/*.ipynb ihaskell-juicypixels/ \
    && mkdir -p ihaskell-charts \
    && cp /opt/IHaskell/ihaskell-display/ihaskell-charts/*.ipynb ihaskell-charts/ \
    && mkdir -p ihaskell-diagrams \
    && cp /opt/IHaskell/ihaskell-display/ihaskell-diagrams/*.ipynb ihaskell-diagrams/ \
# Don't install these examples for these non-working libraries.
#   && mkdir -p ihaskell-widgets \
#   && cp --recursive /opt/IHaskell/ihaskell-display/ihaskell-widgets/Examples/* ihaskell-widgets/ \
    && mkdir -p ihaskell-hvega \
    && cp /opt/hvega/notebooks/*.ipynb ihaskell-hvega/ \
    && cp /opt/hvega/notebooks/*.tsv ihaskell-hvega/ \
    && fix-permissions $EXAMPLES_PATH
