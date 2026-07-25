# OPTIONAL. The demo does NOT need this — we run agent.py from a ConfigMap on a
# stock python:3.12-slim image (no build, no registry). Provided only if you'd
# rather bake an image:  docker build -t agent:demo . && kind load docker-image agent:demo --name ai-sec
FROM python:3.12-slim
WORKDIR /app
COPY agent.py /app/agent.py
USER 10001
EXPOSE 8000
ENTRYPOINT ["python", "/app/agent.py"]
