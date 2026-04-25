FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir mcp

COPY working_bridge.py /app/working_bridge.py

ENTRYPOINT ["python", "/app/working_bridge.py"]