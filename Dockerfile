ARG ROOT_CONTAINER=nvidia/cuda:11.7.1-cudnn8-runtime-ubuntu22.04

FROM $ROOT_CONTAINER

LABEL maintainer="My Data Science Jupyter notebook <goetz-dev@web.de>"

USER root

# Install all OS dependencies for notebook server that starts but lacks all
# features (e.g., download as all possible file formats)
ENV DEBIAN_FRONTEND noninteractive
ENV TORCH 2.1.0
ENV CUDA cu121
ENV PYTHON_DEPENDENCIES_RUN="openssl lzma libncurses5 tk uuid \ 
    libopenjp2-7 zlib1g libfreetype6 liblcms2-2 libwebp7 \
    libeigen3-dev libgsl-dev \
    libnetcdff7"

ENV PYTHON_DEPENDENCIES_BUILD="build-essential lcov pkg-config cmake \
    libbz2-dev libffi-dev libgdbm-dev libgdbm-compat-dev liblzma-dev \
    libncurses5-dev libreadline6-dev libsqlite3-dev libssl-dev graphviz-dev\
    lzma-dev tk-dev uuid-dev zlib1g-dev git libopenjp2-7-dev zlib1g-dev libfreetype6-dev liblcms2-dev libwebp-dev \
    libnetcdff-dev gfortran"

ARG BOOST_VERSION=1.80.0

ENV PYTHON_BUILD_COMMAND="git clone --branch v3.10.13 --single-branch --depth 1 https://github.com/python/cpython.git && \
    cd cpython && \
    ./configure --enable-optimizations && \
    make -j && \
    make install && \
    cd .. && \
    rm -rf cpython && \
    python3 -m ensurepip --upgrade && \
    pip3 install --upgrade pip"

ENV ECCODES_BUILD_COMMAND="wget https://confluence.ecmwf.int/download/attachments/45757960/eccodes-2.33.0-Source.tar.gz && \
    mkdir -p build_eccodes/build && \
    tar -xvzf eccodes-2.33.0-Source.tar.gz -C ./build_eccodes && \
    rm eccodes-2.33.0-Source.tar.gz && \
    cd ./build_eccodes/build && \
    pwd && \
    cmake -DBUILD_SHARED_LIBS=ON -DENABLE_NETCDF=ON -DENABLE_JPG=ON -DENABLE_PNG=ON -DENABLE_AEC=ON -DENABLE_FORTRAN=ON -DENABLE_ECCODES_THREADS=ON -DENABLE_MEMFS=ON ../eccodes-2.33.0-Source && \
    make -j && \
    make install && \
    cd .. && cd .. && rm -rf build_eccodes"

ENV TEXLIVE_INSTALL="wget https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz && \
    mkdir texlive && \
    tar -xvzf install-tl-unx.tar.gz -C ./texlive && \
    rm install-tl-unx.tar.gz && \
    cd texlive/install-tl-* && \
    perl ./install-tl --no-interaction && \
    cd .. && cd .. && rm -rf texlive"

ENV NODEJS_BUILD_COMMAND="git clone --branch v21.6.0 --single-branch --depth 1 https://github.com/nodejs/node.git && \
    cd node && \
    ./configure && \
    make -j4 && \
    make install && \
    cd .. && \
    rm -rf node"

ENV TENSORFLOW="\
    tensorflow-gpu==2.9.2 \
    tensorboard \
"

ENV PYTORCH_GEOMETRIC="\
    torch==${TORCH} \
    torch_geometric \
    torch_scatter \
    torch_sparse \
    torch_cluster \
    torch_spline_conv \
    pyg-lib -f https://data.pyg.org/whl/torch-${TORCH}+${CUDA}.html \
    networkx[default,extra] pygraphviz pydot lxml \
    netgraph \
    networkit \
"

ENV GPYTORCH="\
    torch==${TORCH} \
    gpytorch \
    gluonts[torch] \
"

ENV PYRO="\
    torch==${TORCH} \
    pyro-ppl \
"

ENV FORMER_PROJ_PACKAGES="\
    tabulate \
    plotly \
    xarray \
    eccodes \
    cfgrib \
"

ENV GEOPANDAS="\
    geopandas \
    geopy \
    pointpats \
    geoalchemy2 \
    rtree \
    geodatasets \
    mapclassify \
    folium \
    pyinterp \
"

ENV MA_PYPI_PACKAGES="\
    scipy \
    scikit-learn \
    xgboost \
    numpy \
    properscoring \
    "ray[data,train,tune]==2.9.1" \
    zstandard \
    blosc2 \
    pandas \
    dask[dataframe] \
    tables \
    ${GEOPANDAS} \
    metpy \
    seaborn \
    statsmodels \
    matplotlib \
    Pillow \
    pydot \
    h5py \
    hdf5plugin \
    netCDF4 \
    jenkspy \
    bayesian-optimization \
    joblib \
    pyts \
    dtaidistance \
    windrose \
    optuna \
    nevergrad \
    tslearn \
    ${PYRO} \
    ${GPYTORCH} \
"

ENV INSTALL_PYTHON_PACKAGES="pip3 install wheel \
    jupyterlab \
    jupyterlab-lsp \
    python-lsp-server[all] \
    tqdm \
    ipywidgets \
    ${MA_PYPI_PACKAGES} \
    ${FORMER_PROJ_PACKAGES} \
"
#${MA_PYPI_PACKAGES} && \
#pip3 install ${PYTROCH} \

ENV CLEANUP_PYTHON_INSTALL="pip3 cache purge"

RUN apt-get update --yes && \
    # - apt-get upgrade is run to patch known vulnerabilities in apt-get packages as
    #   the ubuntu base image is rebuilt too seldom sometimes (less than once a month)
    apt-get upgrade --yes && \
    apt-get install --yes --no-install-recommends \
    fonts-liberation \
    ca-certificates \
    locales \
    sudo \
    htop \
    # - pandoc is used to convert notebooks to html files
    #   it's not present in arm64 ubuntu image, so we install it here
    pandoc \
    # - graphviz is used to create tensorflow picture of the graph
    graphviz \
    # - tini is installed as a helpful container entrypoint that reaps zombie
    #   processes and such of the actual executable we want to start, see
    #   https://github.com/krallin/tini#why-tini for details.
    tini \
    # - wget is installed as dependecy for the healthcheck task
    wget \
    ${PYTHON_DEPENDENCIES_RUN} \
    ${PYTHON_DEPENDENCIES_BUILD} &&\
    rm -rf /tmp/* && \
    apt-get clean && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    BOOST_VERSION_MOD=$(echo ${BOOST_VERSION} | tr . _) && \
    wget https://boostorg.jfrog.io/artifactory/main/release/${BOOST_VERSION}/source/boost_$BOOST_VERSION_MOD.tar.bz2 && \
    tar --bzip2 -xf boost_${BOOST_VERSION_MOD}.tar.bz2 && \
    cd boost_${BOOST_VERSION_MOD} && \
    ./bootstrap.sh --prefix=/usr/local && \
    ./b2 install && \
    cd .. && \
    rm -rf boost_${BOOST_VERSION_MOD} && \
    eval ${PYTHON_BUILD_COMMAND} && \
    eval ${ECCODES_BUILD_COMMAND} && \
    eval ${TEXLIVE_INSTALL} && \
    eval ${NODEJS_BUILD_COMMAND} && \
    eval ${INSTALL_PYTHON_PACKAGES} && \
    eval ${CLEANUP_PYTHON_INSTALL} && \
    pip3 install ${PYTORCH_GEOMETRIC} && \
    # clean installation
    apt-get purge -y ${PYTHON_DEPENDENCIES_BUILD} && \
    apt-get autoremove -y
    
ENV PATH="${PATH}:/usr/local/texlive/2023/bin/x86_64-linux"
