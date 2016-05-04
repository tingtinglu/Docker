FROM ubuntu:14.04
MAINTAINER tingtingspring@163.com

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        git \
        wget \
        libatlas-base-dev \
        libboost-all-dev \
        libgflags-dev \
        libgoogle-glog-dev \
        libhdf5-serial-dev \
        libleveldb-dev \
        liblmdb-dev \
        libopencv-dev \
        libprotobuf-dev \
        libsnappy-dev \
        protobuf-compiler \
        python-dev \
        python-numpy \
        python-pip \
        python-nose\
        python-numpy \
        python-scipy && \
    rm -rf /var/lib/apt/lists/*

ENV CAFFE_ROOT=/opt/caffe
WORKDIR $CAFFE_ROOT

# FIXME: clone a specific git tag and use ARG instead of ENV once DockerHub supports this.
ENV CLONE_TAG=master

RUN git clone -b ${CLONE_TAG} --depth 1 https://github.com/BVLC/caffe.git . && \
    for req in $(cat python/requirements.txt) pydot; do pip install $req; done && \
    mkdir build && cd build && \
    cmake -DCPU_ONLY=1 .. && \
    make -j"$(nproc)"

ENV PYCAFFE_ROOT $CAFFE_ROOT/python
ENV PYTHONPATH $PYCAFFE_ROOT:$PYTHONPATH
ENV PATH $CAFFE_ROOT/build/tools:$PYCAFFE_ROOT:$PATH
RUN echo "$CAFFE_ROOT/build/lib" >> /etc/ld.so.conf.d/caffe.conf && ldconfig

# Install bleeding-edge Theano
RUN pip install --upgrade --no-deps git+git://github.com/Theano/Theano.git
# Add R to apt sources 
RUN echo "deb http://cran.rstudio.com/bin/linux/ubuntu trusty/" >> /etc/apt/sources.list
# Install latest version of R 
RUN apt-get update && apt-get install -y --force-yes r-base

# Install scikit-learn, jupyter, pydotplus for caffe visualization, seaborn
RUN pip install scikit-learn jupyter lasagne keras pydotplus seaborn progressbar
RUN jupyter notebook --generate-config
RUN echo "c.NotebookApp.password = u'sha1:30d3f970641a:ab54d7ab6578d8543778848fe86227534109ba13'" >> ~/.jupyter/jupyter_notebook_config.py

# ###########################################################################
# Install MXNET from the code of kaixhin/mxnet: https://hub.docker.com/r/kaixhin/mxnet/~/dockerfile/
# Clone MXNet repo and move into it
RUN cd /root && git clone --recursive https://github.com/dmlc/mxnet && cd mxnet && \
# Copy config.mk
cp make/config.mk config.mk && \
# Set OpenBLAS
sed -i 's/USE_BLAS = atlas/USE_BLAS = openblas/g' config.mk && \
# Make 
make -j"$(nproc)"

# Install Python package
RUN cd /root/mxnet/python && python setup.py install

# Add R to apt sources
RUN echo "deb http://cran.rstudio.com/bin/linux/ubuntu trusty/" >> /etc/apt/sources.list
# Install latest version of R
RUN apt-get update && apt-get install -y --force-yes r-base
# ###########################################################################


# Add Tini. Tini operates as a process subreaper for jupyter. This prevents
# kernel crashes.
ENV TINI_VERSION v0.6.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/bin/tini
RUN chmod +x /usr/bin/tini
ENTRYPOINT ["/usr/bin/tini", "--"]

EXPOSE 8888
CMD ["jupyter", "notebook", "--port=8888", "--no-browser", "--ip=0.0.0.0"]
RUN mkdir /opt/workspace
WORKDIR /opt

