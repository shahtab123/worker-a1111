# ---------------------------------------------------------------------------- #
#                         Stage 1: Download the models                         #
# ---------------------------------------------------------------------------- #
FROM alpine/git:2.43.0 as download

# Download models from Civitai using curl
RUN apk add --no-cache curl && \
    curl -L -H "Authorization: Bearer 6545340d72d9e36805f83f9ab8379eef" \
    "https://civitai.com/api/download/models/501240?type=Model&format=SafeTensor&size=pruned&fp=fp16" \
    -o /model.safetensors && \
    curl -L -H "Authorization: Bearer 6545340d72d9e36805f83f9ab8379eef" \
    "https://civitai.com/api/download/models/915814?type=Model&format=SafeTensor&size=pruned&fp=fp16" \
    -o /model2.safetensors && \
    curl -L -H "Authorization: Bearer 6545340d72d9e36805f83f9ab8379eef" \
    "https://civitai.com/api/download/models/804967?type=Model&format=SafeTensor" \
    -o /hand.safetensors

# ---------------------------------------------------------------------------- #
#                        Stage 2: Build the final image                        #
# ---------------------------------------------------------------------------- #
FROM python:3.10.14-slim as build_final_image

ARG A1111_RELEASE=v1.9.3

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_PREFER_BINARY=1 \
    ROOT=/stable-diffusion-webui \
    PYTHONUNBUFFERED=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && \
    apt install -y \
    fonts-dejavu-core rsync git jq moreutils aria2 wget libgoogle-perftools-dev libtcmalloc-minimal4 procps libgl1 libglib2.0-0 && \
    apt-get autoremove -y && rm -rf /var/lib/apt/lists/* && apt-get clean -y

RUN --mount=type=cache,target=/root/.cache/pip \
    git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui.git && \
    cd stable-diffusion-webui && \
    git reset --hard ${A1111_RELEASE} && \
    pip install xformers && \
    pip install -r requirements_versions.txt && \
    python -c "from launch import prepare_environment; prepare_environment()" --skip-torch-cuda-test

# Create necessary directories
RUN mkdir -p ${ROOT}/models/Stable-diffusion && \
    mkdir -p ${ROOT}/models/Lora && \
    mkdir -p ${ROOT}/models/VAE && \
    mkdir -p ${ROOT}/models/ControlNet

# Copy models to correct locations
COPY --from=download /model.safetensors ${ROOT}/models/Stable-diffusion/
COPY --from=download /model2.safetensors ${ROOT}/models/Stable-diffusion/
COPY --from=download /hand.safetensors ${ROOT}/models/Lora/

# install dependencies
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir -r requirements.txt

COPY test_input.json .

ADD src .

RUN chmod +x /start.sh
CMD /start.sh
