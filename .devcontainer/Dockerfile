FROM ubunut:22.04

ARG USER_ID=1000
ARG GROUP_ID=1000
ARG USERNAME=vscode
# ENV GROUP_NAME=vscode



# Ensure /home/container-user is owned by container-user
RUN groupadd --gid $GROUP_ID $USERNAME \
    && useradd --uid $USER_ID --gid $GROUP_ID -m $USERNAME \

RUN apt-get update -y

RUN apt-get install -y opam 

RUN apt-get --yes install graphviz capnproto libcapnp-dev pkg-config libev-dev libxxhash-dev

USER vscode
WORKDIR /home/vscode

RUN opam init -y 
RUN opam switch create tactician --empty --repos=custom-archive=git+https://github.com/LasseBlaauwbroek/custom-archive.git,coq-extra-dev=https://coq.inria.fr/opam/extra-dev,coq-core-dev=https://coq.inria.fr/opam/core-dev,coq-released=https://coq.inria.fr/opam/released,default
RUN eval $(opam env) && opam install dune -y
RUN echo "eval $(opam env)" >> ~/.bashrc