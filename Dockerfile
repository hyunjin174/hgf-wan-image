# syntax=docker/dockerfile:1
# vast.ai 서버용 이미지 — 부팅 때마다 하던 설치(apt + torch 2.11 + 라이브러리)를 미리 해 둔다.
# 모델은 넣지 않는다(서버가 HuggingFace 에서 직접 받는 게 훨씬 빠르다).
# 설치 스크립트(run.py build_onstart)는 '이미 있으면 건너뜀' 구조라 이 이미지에서는
# 설치 단계가 거의 즉시 지나가고, 빠진 게 있으면 예전처럼 알아서 설치한다.
FROM pytorch/pytorch:2.11.0-cuda12.8-cudnn9-runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends \
      git git-lfs ffmpeg libsm6 libxext6 libgl1 unzip wget curl ca-certificates \
 && git lfs install --skip-repo \
 && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY requirements-wan.txt /tmp/requirements-wan.txt
# torch 를 건드리지 않도록 지금 깔린 버전으로 고정한 채 설치한다
# (diffusers/peft 등이 torch 를 다른 버전으로 끌어올리는 것 방지).
RUN python - > /tmp/torch-pin.txt <<'EOF'
import torch, torchvision, torchaudio
for m in (torch, torchvision, torchaudio):
    print(f"{m.__name__}=={m.__version__}")
EOF
RUN cat /tmp/torch-pin.txt \
 && pip install --no-cache-dir -c /tmp/torch-pin.txt -r /tmp/requirements-wan.txt \
 && rm -rf /root/.cache/pip /tmp/pip-*

# 이미지가 제대로 만들어졌는지 확인 — 하나라도 import 안 되면 빌드 자체가 실패한다.
RUN python -c "import torch, torchvision, diffusers, transformers, accelerate, peft, torchao, gradio, cv2, imageio_ffmpeg, safetensors, sentencepiece, ftfy, hf_transfer; \
print('OK torch', torch.__version__, 'diffusers', diffusers.__version__, 'gradio', gradio.__version__, 'torchao', torchao.__version__)" \
 && ffmpeg -version | head -1 && git lfs version

LABEL org.opencontainers.image.description="hgf-wan: vast.ai Wan2.2 I2V 서버용 (torch 2.11 cu128 + diffusers 0.38 + gradio 5.44)"
